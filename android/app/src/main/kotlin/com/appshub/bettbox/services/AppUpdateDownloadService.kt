package com.appshub.bettbox.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.appshub.bettbox.MainActivity
import com.appshub.bettbox.R
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlin.math.roundToInt

class AppUpdateDownloadService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var downloadJob: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> beginDownload()
            ACTION_RESTORE_NOTIFICATION -> restoreCurrentNotification()
            else -> restoreCurrentNotification()
        }
        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun beginDownload() {
        if (downloadJob?.isActive == true) return

        val state = getState(this)
        if (state[KEY_STATUS] == STATUS_DOWNLOADED &&
            File(state[KEY_FILE_PATH]?.toString().orEmpty()).isFile
        ) {
            showCompletedNotification(state)
            stopSelf()
            return
        }

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildProgressNotification(state))
        downloadJob = scope.launch {
            runDownload()
        }
    }

    private fun runDownload() {
        val prefs = preferences(this)
        val url = prefs.getString(KEY_URL, null).orEmpty()
        val fileName = File(prefs.getString(KEY_FILE_NAME, null).orEmpty()).name
            .ifEmpty { "Bettbox-update.apk" }
        val checksum = prefs.getString(KEY_CHECKSUM, null)?.takeIf { it.isNotBlank() }
        if (url.isEmpty()) {
            fail("下载地址为空")
            return
        }

        val updateDir = File(filesDir, UPDATE_DIRECTORY).apply { mkdirs() }
        val destination = File(updateDir, fileName)
        val temporary = File(updateDir, "$fileName.part")
        updateDir.listFiles()?.forEach { file ->
            if (file != destination && file != temporary) file.delete()
        }
        destination.delete()
        temporary.delete()

        var connection: HttpURLConnection? = null
        try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = true
                connectTimeout = 30_000
                readTimeout = 30_000
                requestMethod = "GET"
                setRequestProperty("User-Agent", "Bettbox-Android-Updater")
                connect()
            }
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException("HTTP ${connection.responseCode}")
            }

            val totalBytes = connection.contentLengthLong.coerceAtLeast(0L)
            var downloadedBytes = 0L
            var lastSampleBytes = 0L
            var lastSampleAt = System.nanoTime()
            var lastPublishAt = 0L
            setState(
                status = STATUS_DOWNLOADING,
                downloadedBytes = 0L,
                totalBytes = totalBytes,
                speedBytes = 0L,
                error = null,
                filePath = destination.absolutePath,
            )

            connection.inputStream.use { input ->
                temporary.outputStream().buffered().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE * 8)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                        downloadedBytes += count

                        val now = System.nanoTime()
                        val elapsedMillis = (now - lastSampleAt) / 1_000_000
                        if (elapsedMillis >= STATE_UPDATE_INTERVAL_MS) {
                            val speed = ((downloadedBytes - lastSampleBytes) * 1000L) /
                                elapsedMillis.coerceAtLeast(1L)
                            setState(
                                status = STATUS_DOWNLOADING,
                                downloadedBytes = downloadedBytes,
                                totalBytes = totalBytes,
                                speedBytes = speed,
                                error = null,
                                filePath = destination.absolutePath,
                            )
                            if (now - lastPublishAt >= NOTIFICATION_UPDATE_INTERVAL_NS) {
                                notificationManager().notify(
                                    NOTIFICATION_ID,
                                    buildProgressNotification(getState(this@AppUpdateDownloadService)),
                                )
                                lastPublishAt = now
                            }
                            lastSampleAt = now
                            lastSampleBytes = downloadedBytes
                        }
                    }
                }
            }

            if (checksum != null && sha256(temporary) != checksum.lowercase()) {
                throw IllegalStateException("安装包校验失败")
            }
            if (!temporary.renameTo(destination)) {
                temporary.copyTo(destination, overwrite = true)
                temporary.delete()
            }

            setState(
                status = STATUS_DOWNLOADED,
                downloadedBytes = destination.length(),
                totalBytes = destination.length(),
                speedBytes = 0L,
                error = null,
                filePath = destination.absolutePath,
            )
            stopForeground(STOP_FOREGROUND_REMOVE)
            showCompletedNotification(getState(this))
            stopSelf()
        } catch (_: CancellationException) {
            throw CancellationException()
        } catch (error: Throwable) {
            temporary.delete()
            fail(error.message ?: error.javaClass.simpleName)
        } finally {
            connection?.disconnect()
        }
    }

    private fun fail(message: String) {
        setState(
            status = STATUS_FAILED,
            downloadedBytes = 0L,
            totalBytes = 0L,
            speedBytes = 0L,
            error = message,
            filePath = null,
        )
        stopForeground(STOP_FOREGROUND_REMOVE)
        notificationManager().notify(
            NOTIFICATION_ID,
            buildStateNotification("更新下载失败", message, ongoing = false),
        )
        stopSelf()
    }

    private fun restoreCurrentNotification() {
        val state = getState(this)
        when (state[KEY_STATUS]) {
            STATUS_DOWNLOADING -> {
                createNotificationChannel()
                startForeground(NOTIFICATION_ID, buildProgressNotification(state))
                if (downloadJob?.isActive != true) beginDownload()
            }
            STATUS_DOWNLOADED -> {
                createNotificationChannel()
                startForeground(
                    NOTIFICATION_ID,
                    buildStateNotification(
                        "更新已下载",
                        "点击返回 Bettbox 安装",
                        ongoing = false,
                    ),
                )
                stopForeground(STOP_FOREGROUND_DETACH)
                stopSelf()
            }
            STATUS_FAILED -> {
                createNotificationChannel()
                startForeground(
                    NOTIFICATION_ID,
                    buildStateNotification(
                    "更新下载失败",
                    state[KEY_ERROR]?.toString().orEmpty(),
                    ongoing = false,
                    ),
                )
                stopForeground(STOP_FOREGROUND_DETACH)
                stopSelf()
            }
            else -> stopSelf()
        }
    }

    private fun showCompletedNotification(state: Map<String, Any?>) {
        createNotificationChannel()
        val fileName = state[KEY_FILE_NAME]?.toString().orEmpty()
        notificationManager().notify(
            NOTIFICATION_ID,
            buildStateNotification(
                "更新已下载",
                if (fileName.isEmpty()) "点击返回 Bettbox 安装" else "$fileName · 点击安装",
                ongoing = false,
            ),
        )
    }

    private fun buildProgressNotification(state: Map<String, Any?>) =
        NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_light)
            .setContentTitle("正在下载 Bettbox 更新")
            .setContentText(progressText(state))
            .setProgress(100, progressOf(state), state[KEY_TOTAL_BYTES] == 0L)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setContentIntent(openAppPendingIntent())
            .setDeleteIntent(restoreNotificationPendingIntent())
            .build()

    private fun buildStateNotification(title: String, text: String, ongoing: Boolean) =
        NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_light)
            .setContentTitle(title)
            .setContentText(text)
            .setOnlyAlertOnce(true)
            .setAutoCancel(!ongoing)
            .setOngoing(ongoing)
            .setContentIntent(openAppPendingIntent())
            .build()

    private fun openAppPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_OPEN_UPDATE, true)
        }
        return PendingIntent.getActivity(
            this,
            OPEN_APP_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun restoreNotificationPendingIntent(): PendingIntent {
        val intent = Intent(this, AppUpdateDownloadService::class.java).apply {
            action = ACTION_RESTORE_NOTIFICATION
        }
        return PendingIntent.getService(
            this,
            RESTORE_NOTIFICATION_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager().createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "应用更新",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "显示 Bettbox 安装包下载进度"
                setSound(null, null)
            }
        )
    }

    private fun notificationManager() =
        getSystemService(NotificationManager::class.java)

    private fun progressText(state: Map<String, Any?>): String {
        val progress = progressOf(state)
        val speed = (state[KEY_SPEED_BYTES] as? Number)?.toLong() ?: 0L
        return "$progress% · ${formatBytes(speed)}/s"
    }

    private fun progressOf(state: Map<String, Any?>): Int {
        val downloaded = (state[KEY_DOWNLOADED_BYTES] as? Number)?.toLong() ?: 0L
        val total = (state[KEY_TOTAL_BYTES] as? Number)?.toLong() ?: 0L
        return if (total > 0) ((downloaded.toDouble() / total) * 100)
            .roundToInt()
            .coerceIn(0, 100) else 0
    }

    private fun setState(
        status: String,
        downloadedBytes: Long,
        totalBytes: Long,
        speedBytes: Long,
        error: String?,
        filePath: String?,
    ) {
        preferences(this).edit()
            .putString(KEY_STATUS, status)
            .putLong(KEY_DOWNLOADED_BYTES, downloadedBytes)
            .putLong(KEY_TOTAL_BYTES, totalBytes)
            .putLong(KEY_SPEED_BYTES, speedBytes)
            .putString(KEY_ERROR, error)
            .putString(KEY_FILE_PATH, filePath)
            .putLong(KEY_UPDATED_AT, System.currentTimeMillis())
            .apply()
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE * 8)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
    }

    companion object {
        const val EXTRA_OPEN_UPDATE = "open_app_update"

        private const val ACTION_START = "com.appshub.bettbox.action.START_APP_UPDATE"
        private const val ACTION_RESTORE_NOTIFICATION =
            "com.appshub.bettbox.action.RESTORE_APP_UPDATE_NOTIFICATION"
        private const val NOTIFICATION_CHANNEL_ID = "bettbox_app_update"
        private const val NOTIFICATION_ID = 20260806
        private const val OPEN_APP_REQUEST_CODE = 20261
        private const val RESTORE_NOTIFICATION_REQUEST_CODE = 20262
        private const val UPDATE_DIRECTORY = "app_updates"
        private const val PREFERENCES_NAME = "app_update_download"
        private const val STATE_UPDATE_INTERVAL_MS = 400L
        private const val NOTIFICATION_UPDATE_INTERVAL_NS = 800_000_000L

        private const val KEY_STATUS = "status"
        private const val KEY_URL = "url"
        private const val KEY_FILE_NAME = "fileName"
        private const val KEY_RELEASE_TAG = "releaseTag"
        private const val KEY_CHECKSUM = "checksum"
        private const val KEY_DOWNLOADED_BYTES = "downloadedBytes"
        private const val KEY_TOTAL_BYTES = "totalBytes"
        private const val KEY_SPEED_BYTES = "speedBytes"
        private const val KEY_FILE_PATH = "filePath"
        private const val KEY_ERROR = "error"
        private const val KEY_UPDATED_AT = "updatedAt"
        private const val KEY_OPEN_REQUESTED = "openRequested"

        private const val STATUS_IDLE = "idle"
        private const val STATUS_DOWNLOADING = "downloading"
        private const val STATUS_DOWNLOADED = "downloaded"
        private const val STATUS_FAILED = "failed"

        private fun preferences(context: Context) =
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

        fun start(
            context: Context,
            url: String,
            fileName: String,
            releaseTag: String,
            checksum: String?,
        ): Boolean {
            if (url.isBlank() || releaseTag.isBlank()) return false
            val current = getState(context)
            val downloadedFile = File(current[KEY_FILE_PATH]?.toString().orEmpty())
            if (current[KEY_STATUS] == STATUS_DOWNLOADED &&
                current[KEY_RELEASE_TAG] == releaseTag &&
                downloadedFile.isFile
            ) {
                return true
            }

            preferences(context).edit()
                .putString(KEY_STATUS, STATUS_DOWNLOADING)
                .putString(KEY_URL, url)
                .putString(KEY_FILE_NAME, File(fileName).name.ifEmpty { "Bettbox-update.apk" })
                .putString(KEY_RELEASE_TAG, releaseTag)
                .putString(KEY_CHECKSUM, checksum)
                .putLong(KEY_DOWNLOADED_BYTES, 0L)
                .putLong(KEY_TOTAL_BYTES, 0L)
                .putLong(KEY_SPEED_BYTES, 0L)
                .remove(KEY_ERROR)
                .apply()

            ContextCompat.startForegroundService(
                context,
                Intent(context, AppUpdateDownloadService::class.java).apply {
                    action = ACTION_START
                },
            )
            return true
        }

        fun retry(context: Context): Boolean {
            val prefs = preferences(context)
            return start(
                context,
                prefs.getString(KEY_URL, null).orEmpty(),
                prefs.getString(KEY_FILE_NAME, null).orEmpty(),
                prefs.getString(KEY_RELEASE_TAG, null).orEmpty(),
                prefs.getString(KEY_CHECKSUM, null),
            )
        }

        fun getState(context: Context): Map<String, Any?> {
            val prefs = preferences(context)
            var status = prefs.getString(KEY_STATUS, STATUS_IDLE) ?: STATUS_IDLE
            val filePath = prefs.getString(KEY_FILE_PATH, null)
            if (status == STATUS_DOWNLOADED && !File(filePath.orEmpty()).isFile) {
                status = STATUS_IDLE
                prefs.edit().putString(KEY_STATUS, status).remove(KEY_FILE_PATH).apply()
            }
            return mapOf(
                KEY_STATUS to status,
                KEY_URL to prefs.getString(KEY_URL, null),
                KEY_FILE_NAME to prefs.getString(KEY_FILE_NAME, null),
                KEY_RELEASE_TAG to prefs.getString(KEY_RELEASE_TAG, null),
                KEY_CHECKSUM to prefs.getString(KEY_CHECKSUM, null),
                KEY_DOWNLOADED_BYTES to prefs.getLong(KEY_DOWNLOADED_BYTES, 0L),
                KEY_TOTAL_BYTES to prefs.getLong(KEY_TOTAL_BYTES, 0L),
                KEY_SPEED_BYTES to prefs.getLong(KEY_SPEED_BYTES, 0L),
                KEY_FILE_PATH to filePath,
                KEY_ERROR to prefs.getString(KEY_ERROR, null),
                KEY_UPDATED_AT to prefs.getLong(KEY_UPDATED_AT, 0L),
            )
        }

        fun install(context: Context, releaseTag: String): Boolean {
            val state = getState(context)
            val file = File(state[KEY_FILE_PATH]?.toString().orEmpty())
            if (state[KEY_STATUS] != STATUS_DOWNLOADED ||
                state[KEY_RELEASE_TAG] != releaseTag ||
                !file.isFile
            ) {
                return false
            }
            val uri: Uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileProvider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            return runCatching {
                context.startActivity(intent)
                true
            }.getOrDefault(false)
        }

        fun restoreNotification(context: Context) {
            val status = getState(context)[KEY_STATUS]
            if (status !in setOf(STATUS_DOWNLOADING, STATUS_DOWNLOADED, STATUS_FAILED)) return
            ContextCompat.startForegroundService(
                context,
                Intent(context, AppUpdateDownloadService::class.java).apply {
                    action = ACTION_RESTORE_NOTIFICATION
                },
            )
        }

        fun markOpenRequested(context: Context) {
            preferences(context).edit().putBoolean(KEY_OPEN_REQUESTED, true).apply()
        }

        fun consumeOpenRequested(context: Context): Boolean {
            val prefs = preferences(context)
            val requested = prefs.getBoolean(KEY_OPEN_REQUESTED, false)
            if (requested) prefs.edit().putBoolean(KEY_OPEN_REQUESTED, false).apply()
            return requested
        }

        private fun formatBytes(bytes: Long): String {
            if (bytes < 1024L) return "$bytes B"
            val units = arrayOf("KB", "MB", "GB")
            var value = bytes.toDouble()
            var unitIndex = -1
            do {
                value /= 1024.0
                unitIndex++
            } while (value >= 1024.0 && unitIndex < units.lastIndex)
            return if (value >= 100) "%.0f %s".format(value, units[unitIndex])
            else "%.1f %s".format(value, units[unitIndex])
        }
    }
}

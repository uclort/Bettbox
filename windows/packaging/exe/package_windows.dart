// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:args/args.dart';
import 'package:liquid_engine/liquid_engine.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const _installerPayloadMagic = 'BETTBOX_SETUP_V1';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('arch', allowed: ['amd64', 'arm64'], mandatory: true)
    ..addFlag('compatible', defaultsTo: false)
    ..addOption('env', defaultsTo: 'pre')
    ..addFlag('dev', defaultsTo: false)
    ..addFlag('portable', defaultsTo: null)
    ..addFlag('installer', defaultsTo: true)
    ..addFlag('temp-safe-launcher', defaultsTo: false);

  final args = parser.parse(arguments);
  final arch = args['arch'] as String;
  final compatible = args['compatible'] as bool;
  final isDev = args['dev'] as bool;
  final makePortable =
      (args['portable'] as bool?) ?? (compatible && arch == 'amd64');
  final makeInstaller = args['installer'] as bool;
  final useTempSafeLauncher = args['temp-safe-launcher'] as bool;

  final desc = compatible ? '$arch-compatible' : arch;

  // 1. Get version from pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found.');
    exit(1);
  }
  final pubspecContent = pubspecFile.readAsStringSync();
  final versionMatch = RegExp(r'^version:\s*([^\s+]+)', multiLine: true).firstMatch(pubspecContent);
  if (versionMatch == null) {
    print('Error: Could not find version in pubspec.yaml.');
    exit(1);
  }
  final appVersion = versionMatch.group(1)!;
  print('App Version: $appVersion');

  final outputBaseName = 'Bettbox-$appVersion-windows-$desc-setup';

  // 2. Parse make_config.yaml
  final configFile = File('windows/packaging/exe/make_config.yaml');
  if (!configFile.existsSync()) {
    print('Error: make_config.yaml not found.');
    exit(1);
  }
  final configContent = configFile.readAsStringSync();
  final makeConfig = loadYaml(configContent) as YamlMap;

  // 3. Define directories
  final buildDirName = arch == 'arm64' ? 'arm64' : 'x64';
  final sourceDir = path.absolute('build/windows/$buildDirName/runner/Release');
  print('Source Directory: $sourceDir');
  if (!Directory(sourceDir).existsSync()) {
    print('Error: Source directory $sourceDir does not exist. Run flutter build first.');
    exit(1);
  }

  // 4. Map variables for Inno Setup template
  final coreExecutableName = isDev ? 'BettboxDevCore.exe' : 'BettboxCore.exe';
  final helperExecutableName = isDev ? 'BettboxDevHelperService.exe' : 'BettboxHelperService.exe';
  final helperServiceName = isDev ? 'BettboxDevHelperService' : 'BettboxHelperService';
  final taskName = isDev ? 'Bettbox Dev' : 'Bettbox';

  // Format locales - resolve file paths to absolute to avoid Inno Setup relative path issues
  final packagingDir = path.absolute('windows/packaging/exe');
  final locales = [];
  if (makeConfig['locales'] != null) {
    for (var locale in makeConfig['locales']) {
      final fileVal = locale['file'] as String?;
      locales.add({
        'lang': locale['lang'],
        // Extract just the filename and resolve against the packaging directory
        'file': fileVal != null ? path.join(packagingDir, path.basename(fileVal)) : null,
      });
    }
  }

  final variables = {
    'APP_ID': makeConfig['app_id'],
    'APP_NAME': makeConfig['app_name'],
    'APP_VERSION': appVersion,
    'EXECUTABLE_NAME': makeConfig['executable_name'] ?? 'Bettbox.exe',
    'DISPLAY_NAME': makeConfig['display_name'] ?? 'Bettbox',
    'PUBLISHER_NAME': makeConfig['publisher'] ?? 'appshub.cc',
    'ARCH': arch == 'arm64' ? 'arm64' : 'x64',
    'PUBLISHER_URL': makeConfig['publisher_url'] ?? 'https://github.com/appshubcc/Bettbox',
    'CREATE_DESKTOP_ICON': true,
    'LAUNCH_AT_STARTUP': true,
    'INSTALL_DIR_NAME': '{autopf64}\\${makeConfig['display_name'] ?? 'Bettbox'}',
    'SOURCE_DIR': sourceDir,
    'OUTPUT_BASE_FILENAME': outputBaseName,
    'LOCALES': locales,
    'SETUP_ICON_FILE': path.absolute('windows/runner/resources/app_icon.ico'),
    'PRIVILEGES_REQUIRED': makeConfig['privileges_required'] ?? 'admin',
    'CORE_EXECUTABLE_NAME': coreExecutableName,
    'HELPER_EXECUTABLE_NAME': helperExecutableName,
    'HELPER_SERVICE_NAME': helperServiceName,
    'TASK_NAME': taskName,
  };

  // 5. Render Liquid template
  final templateFile = File('windows/packaging/exe/inno_setup.iss');
  if (!templateFile.existsSync()) {
    print('Error: inno_setup.iss template not found.');
    exit(1);
  }
  final templateContent = templateFile.readAsStringSync();

  final context = Context.create();
  context.variables = variables;

  final template = Template.parse(
    context,
    Source.fromString(templateContent),
  );

  final renderedContent = '\uFEFF${await template.render(context)}';
  final tempIssFile = File('windows/packaging/exe/temp_setup.iss');
  tempIssFile.writeAsBytesSync(utf8.encode(renderedContent));
  print('Generated temp_setup.iss');

  // 6. Run ISCC.exe
  if (makeInstaller) {
    final isccPath = 'C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe';
    if (!File(isccPath).existsSync()) {
      print('Error: Inno Setup 6 is not installed at $isccPath');
      tempIssFile.deleteSync();
      exit(1);
    }

    print('Running ISCC.exe...');
    final processResult = await Process.run(isccPath, [tempIssFile.path]);
    print(processResult.stdout);
    print(processResult.stderr);

    // Clean up temp ISS file
    if (tempIssFile.existsSync()) {
      tempIssFile.deleteSync();
    }

    if (processResult.exitCode != 0) {
      print('Error: ISCC.exe compilation failed.');
      exit(processResult.exitCode);
    }

    // 7. Move generated installer to dist/
    final generatedInstallerPath = path.join('windows/packaging/exe', '$outputBaseName.exe');
    final generatedInstallerFile = File(generatedInstallerPath);
    if (!generatedInstallerFile.existsSync()) {
      print('Error: Generated installer not found at $generatedInstallerPath');
      exit(1);
    }

    final distDir = Directory('dist');
    if (!distDir.existsSync()) {
      distDir.createSync(recursive: true);
    }

    final targetInstallerPath = path.join('dist', '$outputBaseName.exe');
    if (useTempSafeLauncher) {
      final launcherFile = await _buildInstallerLauncher(arch, appVersion);
      final targetInstallerFile = launcherFile.copySync(targetInstallerPath);
      await _appendInstallerPayload(
        targetInstallerFile: targetInstallerFile,
        payloadFile: generatedInstallerFile,
      );
      generatedInstallerFile.deleteSync();
      print('已生成使用独立临时目录的单文件安装程序。');
    } else {
      generatedInstallerFile.renameSync(targetInstallerPath);
    }
    print('Successfully generated and moved installer to: $targetInstallerPath');
  } else {
    if (tempIssFile.existsSync()) {
      tempIssFile.deleteSync();
    }
  }

  if (makePortable) {
    final distDir = Directory('dist');
    if (!distDir.existsSync()) {
      distDir.createSync(recursive: true);
    }

    final portableDir = Directory(path.join(sourceDir, 'portable'));
    if (!portableDir.existsSync()) {
      portableDir.createSync(recursive: true);
    }
    final keepFile = File(path.join(portableDir.path, '.keep'));
    if (!keepFile.existsSync()) {
      keepFile.writeAsStringSync('');
    }

    final cleanBatSource = File('windows/packaging/portable/clean.bat');
    final cleanBatDest = File(path.join(sourceDir, 'clean.bat'));
    if (cleanBatSource.existsSync()) {
      cleanBatSource.copySync(cleanBatDest.path);
    }

    final portableOutputBaseName = 'Bettbox-$appVersion-windows-$desc-portable.zip';
    final targetPortableZipPath = path.join('dist', portableOutputBaseName);
    final targetPortableFile = File(targetPortableZipPath);
    if (targetPortableFile.existsSync()) {
      targetPortableFile.deleteSync();
    }

    print('Creating portable zip: $targetPortableZipPath');
    try {
      final zipFileEncoder = ZipFileEncoder();
      await zipFileEncoder.zipDirectory(
        Directory(sourceDir),
        filename: targetPortableZipPath,
        followLinks: true,
      );
      print('Successfully generated portable zip: $targetPortableZipPath');
    } finally {
      if (portableDir.existsSync()) {
        portableDir.deleteSync(recursive: true);
      }
      if (cleanBatDest.existsSync()) {
        cleanBatDest.deleteSync();
      }
    }
  }
}

Future<File> _buildInstallerLauncher(String arch, String appVersion) async {
  final sourceDir = path.absolute('windows/packaging/exe/launcher');
  final buildDir = path.absolute('build/windows/installer_launcher/$arch');
  final outputDir = path.absolute(
    'build/windows/installer_launcher/output/$arch',
  );
  final generatorArch = arch == 'arm64' ? 'ARM64' : 'x64';

  final configureResult = await Process.run('cmake', [
    '-S',
    sourceDir,
    '-B',
    buildDir,
    '-A',
    generatorArch,
    '-DBETTBOX_LAUNCHER_OUTPUT_DIR=$outputDir',
    '-DBETTBOX_LAUNCHER_VERSION=$appVersion',
  ]);
  stdout.write(configureResult.stdout);
  stderr.write(configureResult.stderr);
  if (configureResult.exitCode != 0) {
    throw ProcessException(
      'cmake',
      const [],
      '配置 Windows 安装启动器失败。',
      configureResult.exitCode,
    );
  }

  final buildResult = await Process.run('cmake', [
    '--build',
    buildDir,
    '--config',
    'Release',
  ]);
  stdout.write(buildResult.stdout);
  stderr.write(buildResult.stderr);
  if (buildResult.exitCode != 0) {
    throw ProcessException(
      'cmake',
      const [],
      '编译 Windows 安装启动器失败。',
      buildResult.exitCode,
    );
  }

  final launcherFile = File(
    path.join(outputDir, 'BettboxInstallerLauncher.exe'),
  );
  if (!launcherFile.existsSync()) {
    throw FileSystemException('未找到 Windows 安装启动器。', launcherFile.path);
  }
  return launcherFile;
}

Future<void> _appendInstallerPayload({
  required File targetInstallerFile,
  required File payloadFile,
}) async {
  final payloadLength = await payloadFile.length();
  final output = targetInstallerFile.openSync(mode: FileMode.append);
  try {
    await for (final chunk in payloadFile.openRead()) {
      output.writeFromSync(chunk);
    }

    final magic = ascii.encode(_installerPayloadMagic);
    if (magic.length != 16) {
      throw StateError('安装程序载荷标识必须为 16 字节。');
    }
    output.writeFromSync(magic);

    final payloadSize = ByteData(8)
      ..setUint64(0, payloadLength, Endian.little);
    output.writeFromSync(payloadSize.buffer.asUint8List());
  } finally {
    output.closeSync();
  }
}

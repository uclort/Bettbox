// ignore_for_file: avoid_print

import 'dart:io';

String _optionValue(List<String> arguments, String name) {
  final prefix = '--$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) {
      return argument.substring(prefix.length);
    }
  }
  throw ArgumentError('缺少参数 --$name。');
}

String _join(Iterable<String> parts) => parts.join(Platform.pathSeparator);

void main(List<String> arguments) {
  final arch = _optionValue(arguments, 'arch');
  if (arch != 'amd64' && arch != 'arm64') {
    throw ArgumentError('不支持的 Windows 架构：$arch。');
  }

  String? pluginDirectory;
  for (final argument in arguments) {
    if (argument.startsWith('--plugin-dir=')) {
      pluginDirectory = argument.substring('--plugin-dir='.length);
      break;
    }
  }
  final windowsDirectory =
      pluginDirectory ??
      _join([
        'windows',
        'flutter',
        'ephemeral',
        '.plugin_symlinks',
        'auto_updater_windows',
        'windows',
      ]);
  final cmakeFile = File(_join([windowsDirectory, 'CMakeLists.txt']));
  if (!cmakeFile.existsSync()) {
    throw FileSystemException(
      '未找到 auto_updater_windows CMakeLists.txt。',
      cmakeFile.path,
    );
  }

  var source = cmakeFile.readAsStringSync();
  final winsparkleDirectoryMatch = RegExp(
    r'set\(WIN_SPARKLE_DIR "\$\{CMAKE_CURRENT_SOURCE_DIR\}/([^"]+)"\)',
  ).firstMatch(source);
  if (winsparkleDirectoryMatch == null) {
    throw StateError('无法定位 WinSparkle 源目录。');
  }
  final winsparkleArch = arch == 'arm64' ? 'ARM64' : 'x64';
  final releaseDirectory = Directory(
    _join([
      windowsDirectory,
      winsparkleDirectoryMatch.group(1)!,
      winsparkleArch,
      'Release',
    ]),
  );
  for (final fileName in const ['WinSparkle.dll', 'WinSparkle.lib']) {
    final file = File(_join([releaseDirectory.path, fileName]));
    if (!file.existsSync()) {
      throw FileSystemException(
        'auto_updater_windows 缺少 $winsparkleArch 版本的 $fileName。',
        file.path,
      );
    }
  }

  for (final extension in const ['dll', 'lib']) {
    final pattern = RegExp(
      r'\$\{WIN_SPARKLE_DIR\}/(?:x64|ARM64)/Release/WinSparkle\.' + extension,
    );
    if (pattern.allMatches(source).length != 1) {
      throw StateError('无法唯一定位 WinSparkle.$extension 的架构路径。');
    }
    source = source.replaceFirst(
      pattern,
      '\${WIN_SPARKLE_DIR}/$winsparkleArch/Release/WinSparkle.$extension',
    );
  }
  cmakeFile.writeAsStringSync(source);
  print('auto_updater_windows 已切换到 WinSparkle $winsparkleArch。');
}

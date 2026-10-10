#!/usr/bin/env bash
set -euo pipefail

# BETTBOX-CUSTOM: 发布包会移除开发模块；编译测试只使用 Pod/SDK 开发框架。
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_dir}"
app_path="${1:?请指定构建完成的 macOS App}"
arch="${2:?请指定 arm64 或 amd64}"
case "${arch}" in
  arm64|amd64) ;;
  *) echo "不支持的架构：${arch}" >&2; exit 1 ;;
esac
# 格式化测试与安装包架构无关，按 Runner 架构运行，避免依赖 Rosetta。
case "$(uname -m)" in
  arm64) test_target="arm64-apple-macosx11.0" ;;
  x86_64) test_target="x86_64-apple-macosx10.15" ;;
  *) echo "不支持的测试主机架构。" >&2; exit 1 ;;
esac
flutter_root="${FLUTTER_ROOT:-$(sed -n 's/^FLUTTER_ROOT=//p' macos/Flutter/ephemeral/Flutter-Generated.xcconfig)}"
sparkle_frameworks="${repo_dir}/macos/Pods/Sparkle"
flutter_frameworks="${flutter_root}/bin/cache/artifacts/engine/darwin-x64-release/FlutterMacOS.xcframework/macos-arm64_x86_64"
for framework in "${sparkle_frameworks}/Sparkle.framework" "${flutter_frameworks}/FlutterMacOS.framework"; do
  if [[ ! -d "${framework}/Headers" || ! -d "${framework}/Modules" ]]; then
    echo "缺少编译所需开发框架：${framework}" >&2
    exit 1
  fi
done
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/bettbox-updater-test.XXXXXX")"
trap 'rm -rf "${test_dir}"' EXIT
swiftc -target "${test_target}" -F "${sparkle_frameworks}" -F "${flutter_frameworks}" \
  -framework Sparkle -framework FlutterMacOS \
  -Xlinker -rpath -Xlinker "${sparkle_frameworks}" \
  -Xlinker -rpath -Xlinker "${flutter_frameworks}" \
  plugins/auto_updater_macos/macos/Classes/AutoUpdater.swift \
  plugins/auto_updater_macos/macos/Tests/main.swift \
  -o "${test_dir}/updater-version-test"
"${test_dir}/updater-version-test"

# 本地化验证仍读取最终包，不以 Pod 缓存替代产物校验。
resources="${app_path}/Contents/Frameworks/Sparkle.framework/Resources"
reference="${resources}/zh_CN.lproj/Sparkle.strings"
test -f "${reference}"
plutil -convert json -o "${test_dir}/reference.json" "${reference}"
for strings in "${resources}"/*.lproj/Sparkle.strings; do
  plutil -convert json -o "${test_dir}/translation.json" "${strings}"
  python3 - "${test_dir}/reference.json" "${test_dir}/translation.json" "${strings}" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as reference:
    expected = json.load(reference)
with open(sys.argv[2], encoding='utf-8') as translation:
    actual = json.load(translation)
if expected != actual:
    raise SystemExit(f'正式包 Sparkle 中文资源不一致：{sys.argv[3]}')
if actual.get('Install Update') != '安装更新':
    raise SystemExit('正式包缺少 Sparkle 中文按钮文本')
PY
done
echo "正式包 Sparkle 中文资源校验通过。"

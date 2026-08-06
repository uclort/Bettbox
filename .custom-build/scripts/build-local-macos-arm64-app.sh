#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(git rev-parse --show-toplevel)"
custom_repo="${repo_dir}/.custom-build/runtime/custom-mihomo"
custom_source="${custom_repo}/source"
expected_custom_commit="$(
  tr -d '[:space:]' < "${repo_dir}/.custom-build/metadata/custom-mihomo-commit"
)"

if [[ ! -d "${custom_repo}/.git" ]]; then
  mkdir -p "$(dirname "${custom_repo}")"
  git clone --filter=blob:none --no-checkout \
    git@github.com:uclort/custom-mihomo.git \
    "${custom_repo}"
fi

git -C "${custom_repo}" checkout --detach "${expected_custom_commit}"
actual_custom_commit="$(git -C "${custom_repo}" rev-parse HEAD)"
if [[ "${actual_custom_commit}" != "${expected_custom_commit}" ]]; then
  echo "错误：自定义 Mihomo 提交不匹配。" >&2
  exit 1
fi

rustc_path="$(rustup which rustc --toolchain stable)"
rustdoc_path="$(rustup which rustdoc --toolchain stable)"
if [[ ! -x "${rustc_path}" || ! -x "${rustdoc_path}" ]]; then
  echo "错误：未找到 rustup stable 工具链。" >&2
  exit 1
fi

build_dir="$(mktemp -d /private/tmp/bettbox-local-macos.XXXXXX)"
cleanup() {
  git -C "${repo_dir}" worktree remove --force "${build_dir}" \
    >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

git -C "${repo_dir}" worktree add --detach "${build_dir}" HEAD
"${build_dir}/.custom-build/scripts/use-custom-mihomo.sh" \
  "${build_dir}" \
  "${custom_source}"

(
  cd "${build_dir}"
  SENTRY_BACKEND=none flutter pub get
  SENTRY_BACKEND=none dart run build_runner build -d
  SENTRY_BACKEND=none dart setup.dart macos --arch arm64 --out core-only
  RUSTC="${rustc_path}" \
    RUSTDOC="${rustdoc_path}" \
    SENTRY_BACKEND=none \
    flutter build macos \
      --release \
      --no-pub \
      --dart-define=APP_ENV=stable \
      --dart-define=APP_ASSET_SUFFIX=macos-arm64.dmg
)

source_app="${build_dir}/build/macos/Build/Products/Release/Bettbox.app"
if [[ ! -d "${source_app}" ]]; then
  echo "错误：macOS App 构建产物不存在。" >&2
  exit 1
fi

app_version="$(awk '$1 == "version:" { print $2; exit }' "${repo_dir}/pubspec.yaml")"
app_version="${app_version%%+*}"
source_commit="$(git -C "${repo_dir}" rev-parse --short=12 HEAD)"
output_name="${1:-Bettbox-${app_version}-local-${source_commit}-macos-arm64.app}"
output_app="${repo_dir}/dist/${output_name}"

if [[ -e "${output_app}" ]]; then
  echo "错误：产物已存在，不会覆盖：${output_app}" >&2
  exit 1
fi

mkdir -p "${repo_dir}/dist"
ditto "${source_app}" "${output_app}"

core_path="${output_app}/Contents/MacOS/BettboxCore"
file "${core_path}" | grep -q 'arm64'
codesign --verify --deep --strict --verbose=2 "${output_app}"

echo "本地生产 App 构建完成：${output_app}"

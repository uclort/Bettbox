#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/bettbox-login-item.XXXXXX")"
trap 'rm -rf "${test_dir}"' EXIT
cp "${repo_dir}/.custom-build/scripts/legacy_launch_at_login_test.swift" \
  "${test_dir}/main.swift"

swiftc \
  "${repo_dir}/macos/Runner/LegacyLaunchAtLogin.swift" \
  "${test_dir}/main.swift" \
  -o "${test_dir}/legacy-launch-at-login-test"
"${test_dir}/legacy-launch-at-login-test" "${test_dir}"

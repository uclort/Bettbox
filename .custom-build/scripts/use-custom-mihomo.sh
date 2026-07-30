#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "用法：$0 <Bettbox 源码目录> <自定义 Mihomo 源码目录>" >&2
  exit 2
fi

bettbox_dir="$1"
custom_source_dir="$2"
destination_dir="${bettbox_dir}/core/Clash.Meta"
go_mod_file="${custom_source_dir}/go.mod"

if [[ ! -f "${bettbox_dir}/setup.dart" ]]; then
  echo "错误：Bettbox 源码目录无效：${bettbox_dir}" >&2
  exit 1
fi

if [[ ! -f "${go_mod_file}" ]]; then
  echo "错误：缺少自定义内核文件 ${go_mod_file}" >&2
  exit 1
fi

module_name="$(awk '$1 == "module" { print $2; exit }' "${go_mod_file}")"
if [[ "${module_name}" != "github.com/metacubex/mihomo" ]]; then
  echo "错误：自定义内核模块必须是 github.com/metacubex/mihomo，当前为 ${module_name:-未声明}" >&2
  exit 1
fi

mkdir -p "${destination_dir}"
find "${destination_dir}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
cp -R "${custom_source_dir}/." "${destination_dir}/"

if [[ ! -f "${destination_dir}/go.mod" ]]; then
  echo "错误：自定义内核复制失败" >&2
  exit 1
fi

echo "已使用自定义 Mihomo 源码替换 Bettbox 内核。"

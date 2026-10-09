#!/usr/bin/env python3
"""把 vclibs 插件误标为 arm64 的 32 位运行库替换为真正的 ARM64 版本。"""

from __future__ import annotations

import shutil
from pathlib import Path


def main() -> None:
    root = Path.cwd()
    plugin = root / "windows/flutter/ephemeral/.plugin_symlinks/vclibs"
    source_dir = root / ".custom-build/vendor/vclibs-arm64"
    target_dir = plugin / "windows/VCLibs/arm64"
    if not source_dir.is_dir():
        raise SystemExit(f"缺少 ARM64 运行库来源目录：{source_dir}")
    if not plugin.is_dir():
        raise SystemExit(f"未找到 vclibs 插件目录：{plugin}")
    if not target_dir.is_dir():
        raise SystemExit(f"缺少 vclibs ARM64 目标目录：{target_dir}")

    for name in ("msvcp140.dll", "vcruntime140.dll"):
        target = target_dir / name
        if not target.is_file():
            raise SystemExit(f"vclibs ARM64 目录缺少 {name}。")
        shutil.copy2(source_dir / name, target)
        print(f"已替换为 ARM64 运行库：{target}")


if __name__ == "__main__":
    main()

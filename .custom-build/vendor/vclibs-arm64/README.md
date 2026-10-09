# Windows ARM64 VC 运行库

来源：`msix 3.18.0` 包内的 ARM64 VC 运行库。`vclibs 0.1.3` 发布包中名为 `arm64` 的文件实际是 32 位 ARM，不能用于 Windows ARM64。构建时由 `.custom-build/scripts/fix_windows_arm64_vclibs.py` 复制到插件缓存。

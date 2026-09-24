## 修复 macOS 闪退

修复后台输入过滤线程处理 Caps Lock / 输入法相关系统事件时触发主线程断言的问题。特殊事件现在在主线程解析；等待超过 50 毫秒时结束当前保护、恢复输入，不无限等待界面线程。媒体键按下/松开识别、四键长按解锁与独立超时监督保留。

## 下载和安装（无需编译）

- **macOS 26+，Apple 芯片**：下载 `KeyPossum-0.1.1-alpha.1-macos-arm64.dmg`，双击后把 KeyPossum 拖入 Applications。先退出旧版，再替换。也提供 ZIP。
- **Windows 11，Intel/AMD x64**：下载 `KeyPossum-0.1.1-alpha.1-windows-x64.zip`，全部解压后运行 `KeyPossum.exe`，无需安装 .NET。
- `Source code` 是源码；普通用户请选择上面的 DMG 或 Windows ZIP。

macOS 版本仅作临时签名，尚未通过 Apple 公证。首次打开被拦截时，可在“系统设置 → 隐私与安全性”确认来源后选择“仍要打开”。更新后可能需要重新授予辅助功能及输入监控权限，并重新完成 15 秒设备试测。Windows 触控屏仍不支持。

本版是预览版本。自动回归覆盖主线程解析、忙碌超时、媒体键按下/松开和现有解锁状态机；真实设备上的 Caps Lock、输入法切换及媒体键仍需试测。

<p align="center"><img src="assets/keypossum.png" width="140" alt="一只躺在键帽上装死的负鼠"></p>

# KeyPossum · 键盘装死

**给键盘放个小假。** 暂停键盘、鼠标和触控板输入，清洁后按住四个指定键，让它们复活。

[English](README.en.md) · [安装与使用](docs/installation.md) · [测试清单](docs/testing.md) · [GitHub 新手指南](docs/github-guide.md)

[**下载安装包（无需编译）**](https://github.com/DDDCC5/KeyPossum/releases/tag/v0.1.1-alpha.1)

> **0.1.1-alpha.1：修复 macOS 特殊按键事件导致的闪退。** 编译成功不代表所有设备输入都能拦截。首次使用必须进行 15 秒试测，尝试媒体键、鼠标、触控板多指手势，再确认没有输入漏出。发现漏出或不确定时，不要开始清洁。Windows 触控屏尚不支持。实际验证记录见 [verification.md](docs/verification.md)。

## 怎么用

1. 打开应用，阅读提示并授予所需系统权限。
2. 使用随机四键组合，或自行设置四个不同的字母／数字；自定义组合可保存在本机。
3. 同时按下这四个键，检测是否能同时识别；然后全部松开。
4. 倒计时 3 秒后开始试测或清洁。准备期间发生输入会取消倒计时。
5. 小窗口始终置顶，显示组合和剩余时间。
6. **只按住指定四键满 5 秒**即可解锁；少一个、多一个或按住修饰键均会清零。也可以等待 **3 分钟自动恢复**。

四键是防误触手势，不是密码，所以一直显示在窗口里。按英文键帽位置使用，无需 Shift。自定义组合排除 `O/0/I/1`，不允许重复字符。首版按标准英文键位实现；其他键盘布局必须先通过四键检测。

## 系统范围

| 平台 | 首版目标 | 分发方式 |
| --- | --- | --- |
| macOS | 26 或更新，Apple Silicon | DMG 拖入“应用程序”，也提供 ZIP |
| Windows | Windows 11，Intel／AMD x64，非触控屏设备 | 解压完整程序文件夹，运行 `KeyPossum.exe` |

内置和外接输入设备均在试测范围内。设备变化会结束当前会话并要求重新验证。电源键、固件功能、Windows `Ctrl+Alt+Del` 等系统保留操作不在保护范围内。普通应用不能承诺覆盖安全桌面、驱动专用手势或所有厂商扩展。

## 隐私与恢复

- 无账号、服务器、联网功能、遥测或键盘日志。
- 只在本机保存自定义组合和试测确认信息。
- UI 心跳、输入线程定时器和独立监督进程提供分层恢复；异常时优先恢复输入。
- 不禁用系统设备，不安装驱动，不修改系统手势设置。
- 这是一款清洁辅助工具，不能用作防他人操作的安全锁。

## 从源码构建

Mac：安装 Xcode 26+ 或相应 Command Line Tools，在项目根目录运行：

```sh
bash scripts/build-macos.sh
```

Windows：安装 .NET 10 SDK，在项目根目录用 PowerShell 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-windows.ps1
```

脚本先运行核心测试，再打包至 `dist/`。Windows 分发包包含 .NET 运行时，使用者无需另装 SDK。`ExecutionPolicy Bypass` 只用于这一次脚本进程，不修改系统的永久策略。

也可以上传到 GitHub 后使用仓库的 **Build** 工作流构建两个版本。Build 工作流生成构建产物；手动运行 Publish release 工作流，通过双平台检查后发布预览版安装包。

## 项目结构

```text
macos/      Swift 原生应用、输入控制和状态机测试
windows/    C# 原生应用、输入控制和状态机测试
assets/     图标原图、PNG、ICO、ICNS
scripts/    构建、打包与检查脚本
docs/       需求、实现计划、安装、测试与开源指南
.github/    自动构建和问题反馈模板
```

## 后续版本

- 在真实触控屏 Windows 设备上验证可恢复的触控禁用能力。
- 扩展键盘布局和设备覆盖，收集可复现的兼容性测试结果。
- 根据实际需求决定开发者签名、公证和安装器。

欢迎提交问题或改进：[贡献说明](CONTRIBUTING.md)。代码采用 [MIT](LICENSE) 许可证；负鼠图标的生成说明见 [assets/README.md](assets/README.md)。

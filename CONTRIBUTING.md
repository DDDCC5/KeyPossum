# Contributing / 参与贡献

欢迎提交兼容性反馈、翻译和修复。请先阅读 `docs/design.md` 和 `docs/testing.md`。

- 报告问题请包含操作系统版本、芯片架构、内置／外接设备型号、应用版本和复现步骤。不要提交个人密码、录屏中的敏感内容或原始键盘记录。
- 输入拦截或恢复逻辑的改动需要状态机回归测试及对应平台实测。没有对应设备时，明确标注未验证。
- 不加入遥测、开机自启、联网依赖或设备永久禁用功能。
- 翻译默认跟随系统语言；中文与英文应表达同样的保护边界。
- 开发者先运行两个纯逻辑测试，再运行适用的构建脚本。CI 不应启动全局输入锁定。
- 每个 PR 说明具体问题、改动后的行为和验证结果。

Core test commands:

```sh
swift run --package-path macos --scratch-path .cache/swift-build --disable-sandbox SessionTests
dotnet run --project windows/KeyPossum.Core.Tests/KeyPossum.Core.Tests.csproj
```

Use Issues for ordinary compatibility problems. See `SECURITY.md` for sensitive reports. Contributions are accepted under the project's MIT license.

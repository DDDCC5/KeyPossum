# GitHub 小白发布指南

项目文件已整理好。先在自己的两台电脑上试测，再公开发布应用下载。

## 先理解三个地方

- **Repository / 仓库**：存源代码，让别人阅读、改进和自行构建。
- **Actions / 自动构建**：GitHub 运行项目里的脚本，生成两个平台的应用包。
- **Releases / 版本发布**：给普通用户下载应用的地方。GitHub 自动提供的“Source code”只是代码，不是应用。

## 推荐：用 GitHub Desktop 上传

1. 注册并登录 GitHub，安装官方 [GitHub Desktop](https://desktop.github.com/)。
2. 解压交付的 `KeyPossum-source.zip`。里面的 `KeyPossum` 文件夹就是完整项目。
3. 在 GitHub Desktop 选择 **File → Add Local Repository**，指向该文件夹。如果提示还不是 Git 仓库，选择创建仓库，并确认仓库根目录就是含 `README.md`、`macos`、`windows` 的这一层。
4. 如果创建操作导致多出一个同名空文件夹，将交付的源文件放入实际仓库根目录。不要把整个项目再套一层上传；仓库首页应直接看到 `README.md` 和 `.github`。
5. 查看 Changes。应该有源码、图标、文档和 `.github`，不应该有 `.cache`、`.tools`、`bin`、`obj`、个人账号资料。`.gitignore` 已排除构建缓存与 `dist`。
6. 填写提交说明，例如 `Initial KeyPossum alpha`，点击 **Commit to main**。
7. 点击 **Publish repository**，名称填 `KeyPossum`。开源仓库取消 **Keep this code private**，检查公开范围后再发布。

这一步上传的是开源代码。无需上传密码、访问令牌、付费开发者证书或电脑上的其他文件。

## 生成应用包

1. 打开仓库网页的 **Actions** 页面。
2. 选择 **Build** 工作流。初次推送到 `main` 会自动运行，也可以点 **Run workflow** 手动运行。
3. 等 macOS 和 Windows 两个任务显示绿色。红色表示构建失败，打开失败步骤复制错误信息即可协助排查。
4. 打开本次运行底部 **Artifacts**，下载两个平台的产物。Actions 下载包外面可能还有一层 ZIP，解开后才是应用分发 ZIP。
5. 分别在 Mac 和 Windows 11 电脑上测试，并填写 `docs/testing.md` 的结果。Actions 的绿色只说明构建检查通过。

工作流使用 GitHub 标准托管 runner，没有配置付费的大型 runner。实际免费额度和计费规则以你的账号及 [GitHub 官方说明](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions) 为准。

## 发布供别人下载的 Alpha 版本

1. 仓库首页右侧 **Releases → Create a new release**。
2. 创建标签 `v0.1.0-alpha.1`，标题写 `KeyPossum 0.1.0 Alpha 1`。
3. 将 `docs/release-notes.md` 的内容复制为版本说明，并更新真实测试结果。
4. 上传两个应用 ZIP 和对应 SHA-256 校验文件。不需要把本地编译缓存上传到 Releases。
5. 勾选 **Set as a pre-release**。在尚未完成设备验收时，不要标成正式稳定版。
6. 检查上传文件正确后，点击 **Publish release**。

此后普通用户从 Releases 选择自己系统对应的 ZIP 下载即可，不需要懂 Git 或安装开发工具。

## 后续更新

修改代码后，用 GitHub Desktop 提交并推送；Actions 会重新构建。修复版本应使用新版本号和新标签，不要悄悄替换旧版本。接受别人提交的改动前先审查并测试，尤其是输入恢复逻辑。

项目公开仓库：[DDDCC5/KeyPossum](https://github.com/DDDCC5/KeyPossum)。后续可以直接在这个仓库中提交更新和发布版本，无需再创建同名仓库。

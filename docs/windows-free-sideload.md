# Windows 免费真机侧载验证（What2Eat v0.1）

> 说明：这份说明针对 **非越狱、Windows 电脑、免费 Apple Account**。目标是验证用户界面及尝试 HealthKit 授权。**无法保证免费签名保留 HealthKit 权限；不会将侧载成功等同于健康数据读写成功。**

## 1. 构建真机 IPA

1. 在 GitHub Actions 打开 `iOS build, tests & unsigned device IPA` 工作流，使用 `feat/ios-mvp-v0.1` 分支。
2. 等待任务完成，找到 Artifacts → `What2Eat-unsigned-iPhone`，下载 ZIP 并解压出 `What2Eat-unsigned-iphoneos.ipa`。
3. 本 IPA 通过 `xcodebuild -sdk iphoneos CODE_SIGNING_ALLOWED=NO` 编译，目标为 iPhone ARM64，**不是可以双击直接安装的已签名包**。
4. 此 IPA 仍包含项目要求的 HealthKit 能力配置，但是否保留到签名后的安装包，取决于 Apple 签发的 Provisioning Profile 与侧载工具重签结果。

## 2. Windows 安装

建议优先用 [Sideloadly 官网](https://sideloadly.io/) 下载的 Windows 版本：

1. 在 Windows 安装 Apple 网站分发的 **非 Microsoft Store 版本** iTunes 与 iCloud（按 Sideloadly 官方说明）。
2. 数据线连接 iPhone，解锁并点「信任此电脑」；初次安装建议使用 USB。
3. 运行 Sideloadly，把上方 IPA 拖入，选择手机；用自己的 Apple Account 进行签名安装。
4. 若提示缺少授权能力 / 证书权限，保留错误原文；**不要通过删除 HealthKit entitlement 来宣称已完成 HealthKit 测试**。
5. iPhone 如有提示，前往「设置 → 通用 → VPN 与设备管理」信任开发者；到「设置 → 隐私与安全 → 开发者模式」开启开发者模式并按提示重启（以实际系统提示为准）。
6. 打开 What2Eat，查看首页和输入页是否正常，再尝试「连接 Apple 健康」。

也可尝试 [AltStore Classic Windows 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)，需要 AltServer + AltStore，刷新签名必须由它管理。

## 3. 免费 Apple Account 限制

- 签名及设备配置一般 7 天有效，需要在到期前刷新或重新安装。
- 每台设备最多 3 个免费开发 App；免费 Personal Team 最多注册 10 个 App ID 和 3 台设备，相关条目有有效期规则。
- AltStore 自身也占用一项安装名额；使用 Sideloadly 时无额外 AltStore 客户端。
- TestFlight、App Store 分发不支持免费账号。
- 升级/重签时尽量保留原 Bundle ID 与开发者身份；避免卸载导致应用本地数据丢失。

官方：Apple Developer [Developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account/)；[HealthKit access](https://developer.apple.com/documentation/xcode/configuring-healthkit-access)。

## 4. 特别重要：HealthKit entitlement 检查

工程里 `project.yml` 配置了 `com.apple.developer.healthkit: true`，但 **源码声明不是证书授权**。

实际签名需要：

- 可供该 App ID 使用、含有 `com.apple.developer.healthkit = true` 的 Apple Provisioning Profile。
- 签名后的 App entitlement 包含同一权限，且 Team / Bundle ID 匹配。
- 用户在 iOS 健康权限弹窗里选择允许读取和写入所需数据。

什么情况说明没有通过 HealthKit 测试：

- 能正常启动，但点击「连接 Apple 健康」提示 `Missing com.apple.developer.healthkit entitlement`，或系统不显示该 App 的健康数据权限。
- 仅看到权限弹窗，没有实际读/写成功。
- 只有模拟器编译和运行成功。

## 5. 最小验收流程

1. 进入 App，确认首页、添加饮食页可以打开。
2. 输入「米饭150克」，点击本地粗估，确认出现结果和估算范围。
3. 将热量手动改为 1 kcal；如 HealthKit 授权成功，点击「确认并写入苹果健康」。
4. 打开苹果健康 App，搜索「膳食能量」，检查是否有来自 What2Eat 的 1 kcal 记录。
5. 返回 What2Eat 刷新，再查看总摄入是否包含该条记录。完成测试后可在健康 App 中删除这条测试记录。
6. 如果签名成功但 HealthKit 失败：保留「安装成功、界面通过、HealthKit 未通过」的真实结果，记录 Sideloadly 和 What2Eat 中的错误文本。

本版本尚没有照片识别 / DeepSeek / 本地饮食历史储存；免费侧载受限时，可以测试界面，但不能完成真实热量写入闭环。

## 6. 官方链接

- https://developer.apple.com/help/account/reference/supported-capabilities-ios/
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit
- https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows
- https://sideloadly.io/

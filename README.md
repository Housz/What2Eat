# What2Eat

个人极简热量管理 iOS App：SwiftUI + HealthKit。这个分支用于第一轮无 Mac 的云端编译验证，尚不是已完成真机测试的应用。

## MVP 体验流程

1. iPhone 启动 App，点「连接 Apple 健康」，选择授权读取膳食能量、活动能量、静息能量、体重，以及写入膳食能量。
2. 首页展示当天摄入、截至当前的活动和静息能量、最新体重。无数据时显示「—」，不假设数据为 0。
3. 点「记录一餐」，输入食物描述，例如「米饭150克，鸡胸肉150克」。
4. 点「本地快速粗估」生成粗略热量及估算区间；也可以直接手动输入 kcal。
5. 可修改 kcal；**只有明确点击「确认并写入苹果健康」才写入 HealthKit**。
6. 在苹果「健康 → 营养 → 膳食能量」中检查记录来源；回到 App 刷新当天总摄入。

本地粗估只覆盖少数预设食物，**不是 AI，不是完整营养数据库**；对未识别的菜品请手动输入。估算范围不是统计置信区间，也不能代表真实菜品的精度。

## 编译与测试

- 核心 Swift 单测：`swift test --package-path packages/CalorieCore`。
- 无 Mac：GitHub Actions macOS 运行器同时执行 `xcodebuild -sdk iphonesimulator` 和 `-sdk iphoneos` 的无签名编译；生成的 **What2Eat-re-sign-on-Windows.ipa**（临时 ad-hoc 签名，仅用于保留能力请求）可下载后用 Windows 的 Sideloadly 重签安装，但不能直接安装，也不能保证免费签名授予 HealthKit 权限。
- [Windows 免费侧载与 HealthKit 权限验证手册](docs/windows-free-sideload.md)：包含下载安装到验收的具体步骤。
- HealthKit 读写必须在具备合适签名和授权的 iPhone 上进行真实验证。TestFlight 分发需要 Apple Developer Program 会员资格。

## 结构

- `packages/CalorieCore`：纯 Swift 输入、粗略热量估计、用户确认、预算计算与单测。
- `What2Eat/ContentView.swift`：首页与餐食录入确认流程。
- `What2Eat/HealthKitService.swift`：权限申请、读取消耗与体重、保存确认后的摄入。
- `project.yml`：使用 XcodeGen 自动创建 Xcode 工程。
- `.github/workflows/ios.yml`：无签名模拟器构建和核心逻辑测试。

后续计划：可切换 AIProvider（DeepSeek / GPT / Gemini）、照片识别、连续聊天、本地餐食详情持久化、Apple Watch。不在第一版测试范围内。

## 隐私与安全

公开仓库只存源码。不要提交真实饮食和健康数据、照片、API Key、证书或描述文件。访问 HealthKit 数据需要用户授权；用户拒绝读取和不存在数据在部分 HealthKit 查询中难以区分。

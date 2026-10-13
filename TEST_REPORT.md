# MVP test report

## Local checks (2026-10-13)

- Swift version: 6.2.1, Linux.
- `swift test --package-path packages/CalorieCore`: 7 passed, 0 failures.
- Input → provisional estimate & range → explicit confirmation → daily budget scenario passed.
- `swiftc -frontend -parse What2Eat/*.swift`: syntax-only check passed (not an iOS SDK typecheck).
- XcodeGen / iOS SDK compilation: pending GitHub Actions result.
- Device HealthKit read/write: not tested. Requires signed iOS build and physical iPhone.

## Basic flow scenario

Input: 一碗米饭，鸡胸肉150克，青菜一点.
Local estimate: 492.5 kcal, illustrative 344.75–640.25 kcal range.
User-corrected amount: 520 kcal. Test goal: 2,000 kcal. Remaining: 1,480 kcal.

The estimator uses rough fixed per-100g references solely for UI testing; it is not an AI nutrition assessment.

## Next verification

1. Review GitHub Actions macOS XcodeGen and unsigned iOS Simulator build result.
2. Resolve any Apple SDK compilation issues and rerun CI.
3. Configure signing / TestFlight only after builds pass.
4. On a real iPhone, check HealthKit permissions, write one confirmed meal, and verify it appears in the Apple Health app.

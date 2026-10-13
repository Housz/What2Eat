import SwiftUI
import CalorieCore

struct DashboardView: View {
    @StateObject private var health = HealthKitService()
    @AppStorage("dailyGoalKcal") private var dailyGoalKcal = 2000.0
    @State private var showingMealEntry = false

    private var remaining: Double? {
        guard let consumed = health.consumedKcal else { return nil }
        return CalorieBudget.remaining(goal: dailyGoalKcal, consumed: consumed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("今天的饮食预算") {
                    dataRow("已摄入", health.consumedKcal, unit: "kcal")
                    dataRow("每日目标", dailyGoalKcal, unit: "kcal")
                    dataRow("还能摄入", remaining, unit: "kcal")
                    Stepper(value: $dailyGoalKcal, in: 1200...4000, step: 50) {
                        Text("调整目标（测试值，非健康建议）")
                            .font(.footnote)
                    }
                    Button {
                        showingMealEntry = true
                    } label: {
                        Label("记录一餐", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Section("Apple 健康（截至目前）") {
                    dataRow("活动能量", health.activeKcal, unit: "kcal")
                    dataRow("静息能量", health.restingKcal, unit: "kcal")
                    dataRow("最新体重", health.weightKilograms, unit: "kg", digits: 1)
                    Button("连接 Apple 健康") {
                        Task { await health.connectAndRefresh() }
                    }
                    Button("刷新数据") {
                        Task { await health.refresh() }
                    }
                    Text(health.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("能量消耗是今日截至当前的累计值，不直接当作全天热量预算。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Text("第一轮测试使用本地食物粗估和手工校正，尚未接入 AI、拍照或 Apple Watch。只有点击确认才写入 HealthKit。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("What2Eat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加", systemImage: "plus") { showingMealEntry = true }
                }
            }
            .sheet(isPresented: $showingMealEntry) {
                MealEntryView(health: health)
            }
            .task { await health.refresh() }
        }
    }

    private func dataRow(_ title: String, _ value: Double?, unit: String, digits: Int = 0) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let value {
                Text("\(value.formatted(.number.precision(.fractionLength(digits)))) \(unit)")
                    .monospacedDigit()
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }
}

private struct MealEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var health: HealthKitService

    @State private var description = ""
    @State private var kcalText = ""
    @State private var estimate: MealEstimate?
    @State private var message: String?
    @State private var isSaving = false

    private var kcal: Double? {
        guard let value = Double(kcalText.replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value > 0, value <= 10_000 else { return nil }
        return value
    }

    private var range: (Double, Double)? {
        guard let kcal else { return nil }
        if let estimate, abs(estimate.kcal - kcal) < 0.5 {
            return (estimate.lowerKcal, estimate.upperKcal)
        }
        return (kcal * 0.7, kcal * 1.3)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("描述食物") {
                    TextField("例如：米饭150克、鸡胸肉150克", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .onChange(of: description) { _ in
                            estimate = nil
                            kcalText = "" // Avoid saving calories for an old meal after editing its description.
                            message = nil
                        }
                    Button("本地快速粗估") { estimateLocally() }
                    Text("仅识别少量常见食物和重量；暂不是 AI。无法识别时可手动填写热量。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("确认摄入") {
                    HStack {
                        Text("热量")
                        TextField("填写 kcal", text: $kcalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                    if let range {
                        Text("粗略范围：\(Int(range.0.rounded()))–\(Int(range.1.rounded())) kcal")
                    } else {
                        Text("输入热量后，将显示一个仅供参考的不确定范围")
                            .foregroundStyle(.secondary)
                    }
                    Text("苹果健康只保存你确认的热量数值，不保存估算范围。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Button {
                        Task { await saveAfterConfirmation() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving { ProgressView().padding(.trailing, 6) }
                            Text("确认并写入苹果健康")
                            Spacer()
                        }
                    }
                    .disabled(kcal == nil || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .navigationTitle("添加饮食")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func estimateLocally() {
        guard let draft = QuickEstimator.estimate(description) else {
            estimate = nil
            message = "本地粗估未识别这顿饭，请直接填写热量。"
            return
        }
        estimate = draft
        kcalText = String(Int(draft.kcal.rounded()))
        message = "已给出粗估，请按实际份量修正后再确认。"
    }

    private func saveAfterConfirmation() async {
        guard let kcal else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let meal = try ConfirmedMeal(description: description, kcal: kcal)
            try await health.saveConfirmedMeal(meal)
            dismiss()
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
    }
}

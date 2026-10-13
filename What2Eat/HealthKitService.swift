import Foundation
import HealthKit
import CalorieCore

@MainActor
final class HealthKitService: ObservableObject {
    @Published private(set) var consumedKcal: Double?
    @Published private(set) var activeKcal: Double?
    @Published private(set) var restingKcal: Double?
    @Published private(set) var weightKilograms: Double?
    @Published private(set) var statusMessage = "尚未连接 Apple 健康"

    private let healthStore = HKHealthStore()
    private let dietaryType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
    private let activeType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    private let restingType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
    private let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func connectAndRefresh() async {
        do {
            try await requestAuthorization()
            await refresh()
        } catch {
            statusMessage = "健康授权失败：\(error.localizedDescription)"
        }
    }

    private func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        try await healthStore.requestAuthorization(
            toShare: [dietaryType],
            read: [dietaryType, activeType, restingType, weightType]
        )
    }

    func refresh() async {
        guard isAvailable else {
            statusMessage = "当前设备无法访问 HealthKit，请使用 iPhone 真机验证"
            return
        }
        do {
            async let consumed = todaySum(for: dietaryType)
            async let active = todaySum(for: activeType)
            async let resting = todaySum(for: restingType)
            async let weight = latestWeight()
            let values = try await (consumed, active, resting, weight)
            consumedKcal = values.0
            activeKcal = values.1
            restingKcal = values.2
            weightKilograms = values.3
            statusMessage = "已刷新 · 空白数据可能表示未授权或暂无记录"
        } catch {
            statusMessage = "读取失败：\(error.localizedDescription)"
        }
    }

    /// Call only after the user explicitly taps the confirmation button.
    func saveConfirmedMeal(_ meal: ConfirmedMeal) async throws {
        try await requestAuthorization()
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: meal.kcal)
        let sample = HKQuantitySample(
            type: dietaryType,
            quantity: quantity,
            start: Date(),
            end: Date(),
            metadata: [
                HKMetadataKeyFoodType: meal.description,
                HKMetadataKeyExternalUUID: UUID().uuidString
            ]
        )
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume() }
                else { continuation.resume(throwing: HealthError.saveFailed) }
            }
        }
        await refresh()
    }

    private func todaySum(for type: HKQuantityType) async throws -> Double? {
        let beginningOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: beginningOfDay,
            end: Date(),
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error { continuation.resume(throwing: error) }
                else {
                    let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
                    continuation.resume(returning: kcal)
                }
            }
            healthStore.execute(query)
        }
    }

    private func latestWeight() async throws -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else {
                    let sample = samples?.first as? HKQuantitySample
                    continuation.resume(returning: sample?.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                }
            }
            healthStore.execute(query)
        }
    }
}

enum HealthError: LocalizedError {
    case unavailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: return "当前设备不支持 Apple 健康"
        case .saveFailed: return "写入苹果健康失败，请检查授权"
        }
    }
}

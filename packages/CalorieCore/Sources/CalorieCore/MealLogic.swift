import Foundation

public enum MealValidationError: Error, Equatable {
    case emptyDescription
    case invalidCalories
    case invalidRange
}

/// A provisional estimate. This value must never be written to HealthKit until the user confirms it.
public struct MealEstimate: Equatable, Sendable {
    public let description: String
    public let kcal: Double
    public let lowerKcal: Double
    public let upperKcal: Double

    public init(description: String, kcal: Double, lowerKcal: Double, upperKcal: Double) throws {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MealValidationError.emptyDescription }
        guard kcal.isFinite, kcal > 0, kcal <= 10_000 else {
            throw MealValidationError.invalidCalories
        }
        guard lowerKcal.isFinite, upperKcal.isFinite,
              lowerKcal > 0, lowerKcal <= kcal, upperKcal >= kcal, upperKcal <= 20_000 else {
            throw MealValidationError.invalidRange
        }
        self.description = trimmed
        self.kcal = kcal
        self.lowerKcal = lowerKcal
        self.upperKcal = upperKcal
    }

    /// User-edited kcal: the original estimate must not silently override their correction.
    public func confirming(editedKcal: Double) throws -> ConfirmedMeal {
        try ConfirmedMeal(description: description, kcal: editedKcal)
    }
}

public struct ConfirmedMeal: Equatable, Sendable {
    public let description: String
    public let kcal: Double

    public init(description: String, kcal: Double) throws {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MealValidationError.emptyDescription }
        guard kcal.isFinite, kcal > 0, kcal <= 10_000 else {
            throw MealValidationError.invalidCalories
        }
        self.description = trimmed
        self.kcal = kcal
    }
}

public enum CalorieBudget {
    /// A negative result means that the manually configured budget was exceeded.
    public static func remaining(goal: Double, consumed: Double) -> Double? {
        guard goal.isFinite, consumed.isFinite, goal > 0, consumed >= 0 else { return nil }
        return goal - consumed
    }
}

/// Small offline *smoke-test* estimator. Never present it as an AI or a nutrition database.
/// Users can override its result; a future AI provider can replace this adapter.
public enum QuickEstimator {
    private struct Reference {
        let name: String
        let kcalPer100g: Double
        let defaultGrams: Double
    }

    private static let references: [Reference] = [
        .init(name: "鸡胸肉", kcalPer100g: 165, defaultGrams: 150),
        .init(name: "米饭", kcalPer100g: 130, defaultGrams: 150),
        .init(name: "鸡蛋", kcalPer100g: 155, defaultGrams: 55),
        .init(name: "面条", kcalPer100g: 137, defaultGrams: 200),
        .init(name: "香蕉", kcalPer100g: 89, defaultGrams: 120),
        .init(name: "牛奶", kcalPer100g: 61, defaultGrams: 250),
        .init(name: "青菜", kcalPer100g: 50, defaultGrams: 100)
    ]

    public static func estimate(_ input: String) -> MealEstimate? {
        let description = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return nil }

        var total = 0.0
        var hasMatches = false
        var hasUnmeasuredPortions = false
        for food in references where description.contains(food.name) {
            hasMatches = true
            let weight = extractWeight(after: food.name, in: description)
            if weight == nil { hasUnmeasuredPortions = true }
            let grams = weight ?? food.defaultGrams
            guard grams > 0, grams <= 3_000 else { return nil }
            total += grams * food.kcalPer100g / 100
        }
        guard hasMatches, total > 0, total <= 10_000 else { return nil }
        let uncertainty = hasUnmeasuredPortions ? 0.30 : 0.20
        return try? MealEstimate(
            description: description,
            kcal: total,
            lowerKcal: total * (1 - uncertainty),
            upperKcal: total * (1 + uncertainty)
        )
    }

    private static func extractWeight(after name: String, in description: String) -> Double? {
        let pattern = NSRegularExpression.escapedPattern(for: name)
            + #"\s*[:：]?\s*(\d+(?:\.\d+)?)\s*(?:克|[gG])"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
              let range = Range(match.range(at: 1), in: description) else { return nil }
        return Double(description[range])
    }
}

import XCTest
@testable import CalorieCore

final class MealLogicTests: XCTestCase {
    func testWeightedFoodEstimateIncludesRange() throws {
        let value = try XCTUnwrap(QuickEstimator.estimate("米饭150克，鸡胸肉150g"))
        XCTAssertEqual(value.kcal, 442.5, accuracy: 0.01)
        XCTAssertLessThan(value.lowerKcal, value.kcal)
        XCTAssertGreaterThan(value.upperKcal, value.kcal)
        XCTAssertEqual(value.lowerKcal, 354, accuracy: 0.01)
    }

    func testDefaultPortionHasWiderRange() throws {
        let value = try XCTUnwrap(QuickEstimator.estimate("一碗米饭，加鸡蛋"))
        XCTAssertEqual(value.kcal, 280.25, accuracy: 0.01)
        XCTAssertEqual(value.lowerKcal, value.kcal * 0.70, accuracy: 0.01)
    }

    func testUnknownFoodRequiresManualInput() {
        XCTAssertNil(QuickEstimator.estimate("麻婆豆腐"))
        XCTAssertNil(QuickEstimator.estimate("  "))
    }

    func testInvalidCaloriesRejected() {
        XCTAssertThrowsError(try ConfirmedMeal(description: "鸡肉", kcal: -1))
        XCTAssertThrowsError(try ConfirmedMeal(description: "鸡肉", kcal: .infinity))
        XCTAssertThrowsError(try ConfirmedMeal(description: " ", kcal: 100))
    }

    func testConfirmationCanOverrideAnEstimate() throws {
        let draft = try XCTUnwrap(QuickEstimator.estimate("米饭150g"))
        let confirmed = try draft.confirming(editedKcal: 230)
        XCTAssertEqual(confirmed.kcal, 230, accuracy: 0.01)
        XCTAssertEqual(draft.kcal, 195, accuracy: 0.01)
    }

    func testQuickEntryReviewAndBudgetFlow() throws {
        // Input -> provisional estimate/range -> explicit edit/confirmation -> budget.
        let draft = try XCTUnwrap(QuickEstimator.estimate("一碗米饭，鸡胸肉150克，青菜一点"))
        XCTAssertEqual(draft.kcal, 492.5, accuracy: 0.01)
        XCTAssertEqual(draft.lowerKcal, 344.75, accuracy: 0.01)
        XCTAssertEqual(draft.upperKcal, 640.25, accuracy: 0.01)
        let confirmed = try draft.confirming(editedKcal: 520)
        XCTAssertEqual(CalorieBudget.remaining(goal: 2000, consumed: confirmed.kcal), 1480)
    }

    func testBudgetDoesNotUsePartialDailyBurn() {
        XCTAssertEqual(CalorieBudget.remaining(goal: 1900, consumed: 1200), 700)
        XCTAssertEqual(CalorieBudget.remaining(goal: 1900, consumed: 2050), -150)
        XCTAssertNil(CalorieBudget.remaining(goal: 0, consumed: 30))
    }
}

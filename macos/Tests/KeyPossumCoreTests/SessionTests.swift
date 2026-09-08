import Foundation
import KeyPossumCore

final class SessionTests {
    func armed(duration: Double = 180) -> Session {
        var s = Session(keys: [1, 2, 3, 4], duration: duration)
        s.update(keys: [1, 2, 3, 4], now: 0)
        s.update(keys: [], now: 1)
        s.tick(now: 4)
        return s
    }

    func testInvalidAndDuplicateCombinationsAreRejected() {
        for value in ["", "AAB2", "AB01", "ABCI", "ABCO", "ＡBC2", "ABCDE"] {
            XCTAssertNil(Combination.normalize(value), value)
        }
        XCTAssertEqual(Combination.normalize("ab23"), "AB23")
        for _ in 0..<200 {
            let value = Combination.random()
            XCTAssertEqual(value.count, 4)
            XCTAssertEqual(Set(value).count, 4)
            XCTAssertNotNil(Combination.normalize(value))
        }
    }

    func testChordMustBeVerifiedAndReleasedBeforeThreeSecondCountdown() {
        var s = Session(keys: [1, 2, 3, 4])
        s.tick(now: 50)
        XCTAssertEqual(s.phase, .checking)
        s.update(keys: [1, 2, 3, 4, 9], now: 51)
        XCTAssertEqual(s.phase, .checking)
        s.update(keys: [1, 2, 3, 4], now: 52)
        XCTAssertEqual(s.phase, .releaseToPrepare)
        s.update(keys: [], now: 53)
        XCTAssertEqual(s.phase, .preparing)
        s.tick(now: 55.99)
        XCTAssertEqual(s.phase, .preparing)
        s.tick(now: 56)
        XCTAssertEqual(s.phase, .cleaning)
    }

    func testAnyPreparationInputRequiresRecheck() {
        var s = Session(keys: [1, 2, 3, 4])
        s.update(keys: [1, 2, 3, 4], now: 0)
        s.update(keys: [], now: 1)
        s.activity(now: 2)
        s.tick(now: 10)
        XCTAssertEqual(s.phase, .checking)
    }

    func testExactlyFiveContinuousSecondsAndReleaseDraining() {
        var s = armed()
        s.update(keys: [1, 2, 3, 4], now: 5)
        s.tick(now: 9.99)
        XCTAssertEqual(s.phase, .cleaning)
        s.tick(now: 10)
        XCTAssertEqual(s.phase, .draining)
        XCTAssertEqual(s.reason, .chord)
        s.update(keys: [], now: 10.1)
        XCTAssertEqual(s.phase, .finished)
    }

    func testFifthKeyAndReleaseResetHoldAndRepeatDoesNot() {
        var s = armed()
        s.update(keys: [1, 2, 3, 4], now: 5)
        s.update(keys: [1, 2, 3, 4], now: 7) // auto-repeat
        XCTAssertEqual(s.progress(now: 7), 0.4, accuracy: 0.001)
        s.update(keys: [1, 2, 3, 4, 55], now: 8)
        XCTAssertEqual(s.progress(now: 8), 0)
        s.update(keys: [1, 2, 3, 4], now: 9)
        s.update(keys: [1, 2, 3], now: 12)
        XCTAssertEqual(s.progress(now: 12), 0)
        s.update(keys: [1, 2, 3, 4], now: 13)
        s.tick(now: 17.99)
        XCTAssertEqual(s.phase, .cleaning)
        s.tick(now: 18)
        XCTAssertEqual(s.phase, .draining)
    }

    func testTimeoutIsHardCeilingIncludingDraining() {
        var s = armed()
        s.update(keys: [1, 2, 3, 4], now: 178)
        s.tick(now: 183)
        XCTAssertEqual(s.phase, .draining)
        s.tick(now: 184)
        XCTAssertEqual(s.phase, .finished)
        XCTAssertEqual(s.reason, .timeout)
    }

    func testHeldKeysCannotDrainForever() {
        var s = armed()
        s.update(keys: [1, 2, 3, 4], now: 5)
        s.tick(now: 10)
        s.tick(now: 11.5)
        XCTAssertEqual(s.phase, .finished)
    }

    func testBackwardClockDoesNotCreateHoldProgress() {
        var s = armed()
        s.update(keys: [1, 2, 3, 4], now: 8)
        s.tick(now: 3)
        XCTAssertEqual(s.progress(now: 3), 0)
        s.tick(now: 12.9)
        XCTAssertEqual(s.phase, .cleaning)
    }

    func testQualificationHasShortDeadline() {
        var s = armed(duration: 15)
        s.tick(now: 18.99)
        XCTAssertEqual(s.phase, .cleaning)
        s.tick(now: 19)
        XCTAssertEqual(s.phase, .finished)
    }

    func testQueuedModifierTapResetsHoldUsingEventTimeFlags() {
        var s = armed()
        s.update(keys: [1, 2, 3, 4], now: 5)
        // Historical Shift-down still counts even if the hardware has since released it.
        s.update(keys: ModifierState.applying(flags: 0x00020002, to: [1, 2, 3, 4]), now: 8)
        XCTAssertEqual(s.progress(now: 8), 0)
        s.update(keys: ModifierState.applying(flags: 0, to: [1, 2, 3, 4, 56]), now: 8.01)
        s.tick(now: 10)
        XCTAssertEqual(s.phase, .cleaning)
    }

    func testBothModifierSidesAndPhysicalCapsLockAreIndependent() {
        XCTAssertEqual(ModifierState.applying(flags: 0x00020006, to: [1]), [1, 56, 60])
        XCTAssertEqual(ModifierState.applying(flags: 0x00020004, to: [1, 56, 60]), [1, 60])
        XCTAssertEqual(ModifierState.applying(flags: 0x00010080, to: []), [57])
        // Caps Lock stays logically enabled after release; it must no longer count as held.
        XCTAssertEqual(ModifierState.applying(flags: 0x00010000, to: [57]), [])
        XCTAssertEqual(ModifierState.applying(flags: 0x00800000, to: []), [63])
    }
}

func XCTAssertEqual<T: Equatable>(_ value: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    precondition(value == expected, "\(message) expected \(expected), got \(value)", file: file, line: line)
}
func XCTAssertEqual(_ value: Double, _ expected: Double, accuracy: Double, file: StaticString = #file, line: UInt = #line) {
    precondition(abs(value - expected) <= accuracy, "expected \(expected), got \(value)", file: file, line: line)
}
func XCTAssertNil<T>(_ value: T?, _ message: String = "", file: StaticString = #file, line: UInt = #line) { precondition(value == nil, message, file: file, line: line) }
func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value != nil, file: file, line: line) }
@main struct RunTests {
    static func main() {
        let tests = SessionTests()
        tests.testInvalidAndDuplicateCombinationsAreRejected(); print("PASS testInvalidAndDuplicateCombinationsAreRejected")
        tests.testChordMustBeVerifiedAndReleasedBeforeThreeSecondCountdown(); print("PASS testChordMustBeVerifiedAndReleasedBeforeThreeSecondCountdown")
        tests.testAnyPreparationInputRequiresRecheck(); print("PASS testAnyPreparationInputRequiresRecheck")
        tests.testExactlyFiveContinuousSecondsAndReleaseDraining(); print("PASS testExactlyFiveContinuousSecondsAndReleaseDraining")
        tests.testFifthKeyAndReleaseResetHoldAndRepeatDoesNot(); print("PASS testFifthKeyAndReleaseResetHoldAndRepeatDoesNot")
        tests.testTimeoutIsHardCeilingIncludingDraining(); print("PASS testTimeoutIsHardCeilingIncludingDraining")
        tests.testHeldKeysCannotDrainForever(); print("PASS testHeldKeysCannotDrainForever")
        tests.testBackwardClockDoesNotCreateHoldProgress(); print("PASS testBackwardClockDoesNotCreateHoldProgress")
        tests.testQualificationHasShortDeadline(); print("PASS testQualificationHasShortDeadline")
        tests.testQueuedModifierTapResetsHoldUsingEventTimeFlags(); print("PASS testQueuedModifierTapResetsHoldUsingEventTimeFlags")
        tests.testBothModifierSidesAndPhysicalCapsLockAreIndependent(); print("PASS testBothModifierSidesAndPhysicalCapsLockAreIndependent")
        print("All 11 session tests passed.")
    }
}

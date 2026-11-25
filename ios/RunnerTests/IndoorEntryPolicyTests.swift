import XCTest
@testable import Runner
final class IndoorEntryPolicyTests: XCTestCase {
  func testRequiresRecentEvidenceAndActiveObservation() {
    let policy = IndoorEntryPolicy()
    XCTAssertFalse(policy.evaluate(now: 0, observing: true, poor: true))
    policy.arm(now: 0)
    XCTAssertFalse(policy.evaluate(now: 30, observing: false, poor: true))
    XCTAssertFalse(policy.evaluate(now: 60, observing: true, poor: true))
    XCTAssertTrue(policy.evaluate(now: 90, observing: true, poor: true))
    XCTAssertFalse(policy.evaluate(now: 120, observing: true, poor: true))
  }
  func testRecoveryResetsDegradationAndEvidenceExpires() {
    let policy = IndoorEntryPolicy(); policy.arm(now: 0)
    XCTAssertFalse(policy.evaluate(now: 0, observing: true, poor: true))
    XCTAssertFalse(policy.evaluate(now: 29, observing: true, poor: true))
    XCTAssertFalse(policy.evaluate(now: 30, observing: true, poor: false))
    XCTAssertFalse(policy.evaluate(now: 31, observing: true, poor: true))
    XCTAssertTrue(policy.evaluate(now: 61, observing: true, poor: true))
    let expired = IndoorEntryPolicy(); expired.arm(now: 0)
    XCTAssertFalse(expired.evaluate(now: 1201, observing: true, poor: true))
    XCTAssertFalse(expired.evaluate(now: 1231, observing: true, poor: true))
  }
}

import XCTest
@testable import SeeForMeAI

final class AppErrorTests: XCTestCase {
    func testHTTPMapping() {
        XCTAssertEqual(AppError.fromHTTP(status: 401), .invalidCredentials)
        XCTAssertEqual(AppError.fromHTTP(status: 429), .rateLimited)
        XCTAssertEqual(AppError.fromHTTP(status: 503), .providerUnavailable)
        XCTAssertEqual(AppError.fromHTTP(status: 504), .timeout)
    }
    func testURLErrorMapping() {
        XCTAssertEqual(AppError.map(URLError(.timedOut)), .timeout)
        XCTAssertEqual(AppError.map(URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(AppError.map(CancellationError()), .interrupted)
    }
    func testUnknownNeverLeaksRawText() {
        struct Raw: Error, LocalizedError { var errorDescription: String? { "stack trace 0xdead" } }
        XCTAssertFalse(AppError.map(Raw()).message.contains("0xdead"))
    }
    func testRecoveryActions() {
        XCTAssertEqual(AppError.cameraDenied.recovery, .openSystemSettings)
        XCTAssertEqual(AppError.remoteConsentRequired.recovery, .grantConsent)
        XCTAssertEqual(AppError.missingAPIKey.recovery, .configureKey)
    }
}

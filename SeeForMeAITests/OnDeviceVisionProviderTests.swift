import XCTest
@testable import SeeForMeAI

final class OnDeviceVisionProviderTests: XCTestCase {
    func testTextOnlyAnalysisSucceedsOffline() async throws {
        let provider = OnDeviceVisionProvider()
        let req = AnalysisRequest(
            imageJPEG: nil,
            contextText: "INVOICE #98234\nTOTAL DUE: $450.00\nDUE DATE: 25 OCT 2026",
            question: "What is due?",
            history: [],
            detailed: true
        )
        let result = try await provider.analyze(req)

        XCTAssertFalse(result.summary.isEmpty)
        XCTAssertTrue(result.summary.contains("lines of text"))
        XCTAssertTrue(result.uncertainty?.contains("on-device") == true)
    }

    func testNoContextThrows() async {
        let provider = OnDeviceVisionProvider()
        let req = AnalysisRequest(imageJPEG: nil, contextText: nil, question: nil, history: [], detailed: false)
        do {
            _ = try await provider.analyze(req)
            XCTFail("Should throw noContext")
        } catch {
            XCTAssertEqual(error as? AppError, .noContext)
        }
    }
}

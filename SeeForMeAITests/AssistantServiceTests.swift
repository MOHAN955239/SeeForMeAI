import XCTest
import UIKit
@testable import SeeForMeAI

private struct MockProvider: SceneAnalysisProviding {   // tests only
    var result: Result<SceneAnalysisResult, AppError>
    func analyze(_ request: AnalysisRequest) async throws -> SceneAnalysisResult { try result.get() }
}

@MainActor
final class AssistantServiceTests: XCTestCase {
    private func make(consent: Bool, online: Bool, result: Result<SceneAnalysisResult, AppError>) throws -> (AssistantService, ConversationSession) {
        let d = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: d); settings.remoteAnalysisConsent = consent
        let conn = ConnectivityService(startMonitoring: false); conn.setOnlineForTesting(online)
        let hist = HistoryService(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: d)
        let session = ConversationSession()
        try session.setImage(UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in })
        return (AssistantService(settings: settings, connectivity: conn, history: hist, session: session,
                                 providerFactory: { MockProvider(result: result) }), session)
    }
    private let ok = SceneAnalysisResult(summary: "A cup.", detail: "", uncertainty: nil)

    func testConsentRequired() async throws {
        let (a, _) = try make(consent: false, online: true, result: .success(ok))
        do { _ = try await a.analyze(question: nil, detailed: false); XCTFail() } catch { XCTAssertEqual(error as? AppError, .remoteConsentRequired) }
    }
    func testOffline() async throws {
        let (a, _) = try make(consent: true, online: false, result: .success(ok))
        do { _ = try await a.analyze(question: nil, detailed: false); XCTFail() } catch { XCTAssertEqual(error as? AppError, .offline) }
    }
    func testSuccessAppendsContext() async throws {
        let (a, s) = try make(consent: true, online: true, result: .success(ok))
        _ = try await a.analyze(question: "What is it?", detailed: false)
        XCTAssertEqual(s.turns.count, 2)
    }
    func testProviderFailureDoesNotChangeContext() async throws {
        let (a, s) = try make(consent: true, online: true, result: .failure(.rateLimited))
        do { _ = try await a.analyze(question: nil, detailed: false); XCTFail() } catch { XCTAssertEqual(error as? AppError, .rateLimited) }
        XCTAssertTrue(s.turns.isEmpty)
    }
    func testNoContext() async throws {
        let (a, s) = try make(consent: true, online: true, result: .success(ok)); s.reset()
        do { _ = try await a.analyze(question: nil, detailed: false); XCTFail() } catch { XCTAssertEqual(error as? AppError, .noContext) }
    }
}

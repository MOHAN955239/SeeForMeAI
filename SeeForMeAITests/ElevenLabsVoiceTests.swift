import XCTest
@testable import SeeForMeAI

final class ElevenLabsVoiceTests: XCTestCase {
    func testVoiceCatalogContainsCoreVoices() {
        let voices = ElevenVoice.all
        XCTAssertGreaterThanOrEqual(voices.count, 4)
        XCTAssertTrue(voices.contains { $0.name == "Rachel" })
        XCTAssertTrue(voices.contains { $0.name == "Adam" })
        XCTAssertTrue(voices.contains { $0.name == "Bella" })
        XCTAssertTrue(voices.contains { $0.name == "Antoni" })
    }

    func testRequestPayloadHeadersAndSettings() throws {
        let req = try ElevenLabsService.makeRequest(
            text: "Testing ElevenLabs voice for SeeForMe AI",
            apiKey: "xi_test_key_123",
            voiceID: "21m00Tcm4TlvDq8ikWAM",
            modelID: ElevenLabsService.turboModel
        )

        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "xi-api-key"), "xi_test_key_123")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Accept"), "audio/mpeg")

        // URL contains optimize_streaming_latency query item for mobile speed
        XCTAssertTrue(req.url?.query?.contains("optimize_streaming_latency=3") == true)
        XCTAssertTrue(req.url?.query?.contains("output_format=mp3_44100_128") == true)

        let bodyObj = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        XCTAssertEqual(bodyObj["text"] as? String, "Testing ElevenLabs voice for SeeForMe AI")
        XCTAssertEqual(bodyObj["model_id"] as? String, ElevenLabsService.turboModel)

        let settings = bodyObj["voice_settings"] as! [String: Any]
        XCTAssertEqual(settings["stability"] as? Double, 0.5)
        XCTAssertEqual(settings["similarity_boost"] as? Double, 0.75)
    }

    func testMissingElevenKeyThrows() async {
        let service = ElevenLabsService(apiKey: "")
        do {
            _ = try await service.synthesize("Hello")
            XCTFail("Should throw missingAPIKey")
        } catch {
            XCTAssertEqual(error as? AppError, .missingAPIKey)
        }
    }
}

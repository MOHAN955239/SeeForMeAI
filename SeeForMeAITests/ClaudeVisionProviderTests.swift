import XCTest
@testable import SeeForMeAI

final class ClaudeVisionProviderTests: XCTestCase {
    private func envelope(_ text: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["content": [["type": "text", "text": text]]])
    }
    private func body(_ r: URLRequest) -> [String: Any] { try! JSONSerialization.jsonObject(with: r.httpBody!) as! [String: Any] }

    func testRequestHeadersAndImageOnlyInFirstMessage() throws {
        let req = AnalysisRequest(imageJPEG: Data([1, 2, 3]), contextText: nil, question: "What color is the cup?",
                                  history: [.init(role: .user, text: "Briefly describe"), .init(role: .assistant, text: "A table.")], detailed: false)
        let r = try ClaudeVisionProvider.makeURLRequest(req, apiKey: "k", model: "m")
        XCTAssertEqual(r.url?.scheme, "https")
        XCTAssertEqual(r.value(forHTTPHeaderField: "x-api-key"), "k")
        XCTAssertEqual(r.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let msgs = body(r)["messages"] as! [[String: Any]]
        XCTAssertEqual(msgs.map { $0["role"] as! String }, ["user", "assistant", "user"])
        func hasImage(_ m: [String: Any]) -> Bool { (m["content"] as! [[String: Any]]).contains { $0["type"] as? String == "image" } }
        XCTAssertTrue(hasImage(msgs[0])); XCTAssertFalse(hasImage(msgs[2]))
        XCTAssertEqual(body(r)["model"] as? String, "m")
    }

    func testTextOnlyContextRequestHasNoImage() throws {
        let req = AnalysisRequest(imageJPEG: nil, contextText: "SOUP 5", question: "How much is the soup?", history: [], detailed: false)
        let r = try ClaudeVisionProvider.makeURLRequest(req, apiKey: "k", model: "m")
        let first = (body(r)["messages"] as! [[String: Any]])[0]["content"] as! [[String: Any]]
        XCTAssertFalse(first.contains { $0["type"] as? String == "image" })
        XCTAssertTrue(first.contains { ($0["text"] as? String)?.contains("SOUP 5") == true })
    }

    func testRoleAlternationWhenHistoryStartsWithAssistant() throws {
        let req = AnalysisRequest(imageJPEG: nil, contextText: "x", question: nil,
                                  history: [.init(role: .assistant, text: "hi")], detailed: false)
        let msgs = body(try ClaudeVisionProvider.makeURLRequest(req, apiKey: "k", model: "m"))["messages"] as! [[String: Any]]
        XCTAssertEqual(msgs.first?["role"] as? String, "user")
    }

    func testParseValidJSON() throws {
        let r = try ClaudeVisionProvider.parse(data: envelope(#"{"summary":"A cup on a table.","detail":"White cup.","uncertainty":""}"#))
        XCTAssertEqual(r.summary, "A cup on a table."); XCTAssertNil(r.uncertainty)
    }
    func testParseFencedJSON() throws {
        let r = try ClaudeVisionProvider.parse(data: envelope("```json\n{\"summary\":\"Hi\",\"detail\":\"\",\"uncertainty\":\"Blurry\"}\n```"))
        XCTAssertEqual(r.uncertainty, "Blurry")
    }
    func testParsePlainTextFallback() throws {
        XCTAssertEqual(try ClaudeVisionProvider.parse(data: envelope("A red door.")).summary, "A red door.")
    }
    func testParseMalformedThrows() {
        XCTAssertThrowsError(try ClaudeVisionProvider.parse(data: Data("nope".utf8)))
        XCTAssertThrowsError(try ClaudeVisionProvider.parse(data: envelope(#"{"summary":"","detail":"x"}"#)))
        XCTAssertThrowsError(try ClaudeVisionProvider.parse(data: envelope("")))
    }
    func testMissingKeyThrows() async {
        let p = ClaudeVisionProvider(apiKey: "", model: "m")
        do { _ = try await p.analyze(.init(imageJPEG: nil, contextText: "x", question: nil, history: [], detailed: false)); XCTFail() }
        catch { XCTAssertEqual(error as? AppError, .missingAPIKey) }
    }
}

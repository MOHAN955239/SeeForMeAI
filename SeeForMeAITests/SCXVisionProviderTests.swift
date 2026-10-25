import XCTest
@testable import SeeForMeAI

final class SCXVisionProviderTests: XCTestCase {
    private func completionResponse(content: String) -> Data {
        let json: [String: Any] = [
            "id": "scx-chatcmpl-123",
            "choices": [
                [
                    "index": 0,
                    "message": [
                        "role": "assistant",
                        "content": content
                    ],
                    "finish_reason": "stop"
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func body(_ r: URLRequest) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: r.httpBody!) as! [String: Any]
    }

    func testSCXSovereignHeadersAndEndpoint() throws {
        let req = AnalysisRequest(
            imageJPEG: Data([1, 2, 3]),
            contextText: nil,
            question: "What is this equipment?",
            history: [],
            detailed: true
        )
        let endpoint = URL(string: "https://api.scx.ai/v1/chat/completions")!
        let urlReq = try SCXVisionProvider.makeURLRequest(req, apiKey: "scx_live_test_key", endpoint: endpoint, model: "scx-foundation-vision-1")

        XCTAssertEqual(urlReq.url?.absoluteString, "https://api.scx.ai/v1/chat/completions")
        XCTAssertEqual(urlReq.httpMethod, "POST")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "Authorization"), "Bearer scx_live_test_key")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "Content-Type"), "application/json")

        // Validate Australian Sovereign Data Residency Headers
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "X-SCX-Region"), "au-syd-1")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "X-Data-Residency"), "Australia")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "X-SCX-Sovereignty"), "true")

        let bodyObj = body(urlReq)
        XCTAssertEqual(bodyObj["model"] as? String, "scx-foundation-vision-1")

        let messages = bodyObj["messages"] as! [[String: Any]]
        XCTAssertGreaterThanOrEqual(messages.count, 2) // System + User turn
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
    }

    func testSCXMultimodalImageAndOCRContext() throws {
        let jpegData = Data([10, 20, 30])
        let req = AnalysisRequest(
            imageJPEG: jpegData,
            contextText: "PRESSURE: 5.5 BAR",
            question: "Check the meter",
            history: [],
            detailed: false
        )
        let endpoint = SCXVisionProvider.defaultEndpoint
        let urlReq = try SCXVisionProvider.makeURLRequest(req, apiKey: "key", endpoint: endpoint, model: "scx-foundation-vision-1")

        let messages = body(urlReq)["messages"] as! [[String: Any]]
        let userTurn = messages.first { ($0["role"] as? String) == "user" }
        XCTAssertNotNil(userTurn)

        let contents = userTurn!["content"] as! [[String: Any]]
        let hasImage = contents.contains { ($0["type"] as? String) == "image_url" }
        let hasOCR = contents.contains {
            guard let text = $0["text"] as? String else { return false }
            return text.contains("PRESSURE: 5.5 BAR")
        }

        XCTAssertTrue(hasImage)
        XCTAssertTrue(hasOCR)
    }

    func testSCXParseValidJSON() throws {
        let content = #"{"summary":"Digital meter reads 5.5 bar.","detail":"Safe operational range.","uncertainty":""}"#
        let data = completionResponse(content: content)
        let result = try SCXVisionProvider.parse(data: data)

        XCTAssertEqual(result.summary, "Digital meter reads 5.5 bar.")
        XCTAssertEqual(result.detail, "Safe operational range.")
        XCTAssertNil(result.uncertainty)
    }

    func testSCXParseCodeFencedJSON() throws {
        let content = "```json\n{\"summary\":\"Sydney train sign\",\"detail\":\"Platform 2\",\"uncertainty\":\"Glare on top edge\"}\n```"
        let data = completionResponse(content: content)
        let result = try SCXVisionProvider.parse(data: data)

        XCTAssertEqual(result.summary, "Sydney train sign")
        XCTAssertEqual(result.uncertainty, "Glare on top edge")
    }

    func testSCXParsePlainTextFallback() throws {
        let content = "Australian twenty dollar note visible on table."
        let data = completionResponse(content: content)
        let result = try SCXVisionProvider.parse(data: data)

        XCTAssertEqual(result.summary, "Australian twenty dollar note visible on table.")
        XCTAssertEqual(result.detail, "")
        XCTAssertNil(result.uncertainty)
    }

    func testSCXMissingAPIKeyThrows() async {
        let provider = SCXVisionProvider(apiKey: "")
        let req = AnalysisRequest(imageJPEG: nil, contextText: "Sample", question: nil, history: [], detailed: false)
        do {
            _ = try await provider.analyze(req)
            XCTFail("Should have thrown missingAPIKey")
        } catch {
            XCTAssertEqual(error as? AppError, .missingAPIKey)
        }
    }
}

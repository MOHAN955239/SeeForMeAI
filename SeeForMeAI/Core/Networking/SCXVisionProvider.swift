import Foundation

/// Australian Sovereign AI inference provider powered by SCX (Sydney, NSW).
/// Guarantees 100% Australian data residency — visual data and prompts never leave sovereign borders.
/// Compatible with SCXSwiftKit Foundation Models specifications.
struct SCXVisionProvider: SceneAnalysisProviding {
    var apiKey: String
    var endpoint: URL
    var model: String
    var session: URLSession = .shared

    static let defaultEndpoint = URL(string: "https://api.scx.ai/v1/chat/completions")!
    static let defaultModel = "scx-foundation-vision-1"

    static let systemPrompt = """
    You are the sovereign Australian vision engine of SeeForMe AI, running on SCX sovereign infrastructure. Your reply will be read aloud.
    Rules:
    - Describe ONLY what is visible in the image (or in the provided extracted text). Never invent objects, text, brands, distances or hazards.
    - Be concise, plain, and calm. Lead with the most useful information.
    - Spatial relationships: mention only when clearly visible (e.g. "on the counter", "to your right").
    - Australian context: recognize Australian currency (AUD notes and coins), Sydney transit signs (Opal, Sydney Trains, Metro, Light Rail, Ferries), and Australian Work Health & Safety (WHS) signage.
    - If something is unclear, blurry, or cut off, state what is unclear in "uncertainty".
    - Never claim a path or floor is safe or clear of obstacles. Never estimate distances as definite measurements.
    - Never give medical or dosage advice. You may read label text and advise checking with a doctor or pharmacist.
    - Enterprise / Inspection: report gauge readings, barcodes, serials, and hazard warnings factually without speculation.
    Respond with ONLY a JSON object, no markdown code fences, with exactly these keys:
    {"summary": "<one to two short spoken sentences>", "detail": "<optional extra detail, or empty string>", "uncertainty": "<what is unclear, or empty string>"}
    """

    init(apiKey: String, endpoint: URL = defaultEndpoint, model: String = defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
        self.session = session
    }

    func analyze(_ request: AnalysisRequest) async throws -> SceneAnalysisResult {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppError.missingAPIKey }
        let urlRequest = try Self.makeURLRequest(request, apiKey: apiKey, endpoint: endpoint, model: model)
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AppError.map(error)
        }
        guard let http = response as? HTTPURLResponse else { throw AppError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw AppError.fromHTTP(status: http.statusCode) }
        return try Self.parse(data: data)
    }

    // MARK: Request Construction (Pure, Unit-Tested)

    static func currentPrompt(for r: AnalysisRequest) -> String {
        let q = (r.question ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ins = (r.instruction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var base: String
        if !q.isEmpty, !ins.isEmpty {
            base = "Task: \(ins)\nUser question: \(q)"
        } else if !q.isEmpty {
            base = q
        } else if !ins.isEmpty {
            base = ins
        } else {
            base = r.detailed
                ? "Describe this scene in detail: main objects, their positions, visible text, colors, and anything unclear."
                : "Briefly describe what is in front of me."
        }
        if r.detailed, (!q.isEmpty || !ins.isEmpty) {
            base += "\nPlease answer with fuller detail."
        }
        if let st = r.style?.trimmingCharacters(in: .whitespacesAndNewlines), !st.isEmpty {
            base += "\n(\(st))"
        }
        return base
    }

    static func makeURLRequest(_ r: AnalysisRequest, apiKey: String, endpoint: URL, model: String) throws -> URLRequest {
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Append historical conversation turns
        for turn in r.history {
            messages.append(["role": turn.role.rawValue, "content": turn.text])
        }

        // Build the current user turn (multimodal if image present)
        var userContents: [[String: Any]] = []

        if let jpeg = r.imageJPEG {
            let base64 = jpeg.base64EncodedString()
            userContents.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
            ])
        }

        if let ctx = r.contextText, !ctx.isEmpty {
            userContents.append([
                "type": "text",
                "text": "Text recognized on-device by Apple Vision (may contain OCR errors):\n\(ctx)"
            ])
        }

        userContents.append([
            "type": "text",
            "text": currentPrompt(for: r)
        ])

        messages.append(["role": "user", "content": userContents])

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 700,
            "temperature": 0.2
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // Sovereign Infrastructure Headers
        req.setValue("au-syd-1", forHTTPHeaderField: "X-SCX-Region")
        req.setValue("Australia", forHTTPHeaderField: "X-Data-Residency")
        req.setValue("true", forHTTPHeaderField: "X-SCX-Sovereignty")

        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    // MARK: Response Parsing (Pure, Unit-Tested)

    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let role: String?
                let content: String?
            }
            let message: Message?
        }
        let choices: [Choice]?
    }

    private struct Payload: Decodable {
        let summary: String?
        let detail: String?
        let uncertainty: String?
    }

    static func parse(data: Data) throws -> SceneAnalysisResult {
        guard let resp = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
              let firstChoice = resp.choices?.first,
              let content = firstChoice.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw AppError.malformedResponse
        }

        // Try extracting JSON payload
        if let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end,
           let jsonData = String(content[start...end]).data(using: .utf8),
           let p = try? JSONDecoder().decode(Payload.self, from: jsonData) {
            let summary = (p.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else { throw AppError.malformedResponse }
            let unc = (p.uncertainty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return SceneAnalysisResult(
                summary: summary,
                detail: (p.detail ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                uncertainty: unc.isEmpty ? nil : unc
            )
        }

        // If returned plain text without JSON markers
        if !content.contains("{") {
            return SceneAnalysisResult(summary: content, detail: "", uncertainty: nil)
        }

        throw AppError.malformedResponse
    }
}

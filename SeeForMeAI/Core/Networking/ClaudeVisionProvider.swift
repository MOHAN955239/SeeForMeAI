import Foundation

/// Remote image understanding via the Anthropic Messages API (HTTPS).
/// The image (downscaled JPEG) leaves the device ONLY when this provider is called,
/// which AssistantService allows only after explicit user consent.
struct ClaudeVisionProvider: SceneAnalysisProviding {
    var apiKey: String
    var model: String
    var session: URLSession = .shared

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static let systemPrompt = """
    You are the vision engine of SeeForMe AI, an app for blind and low-vision people. Your reply will be read aloud.
    Rules:
    - Describe ONLY what is visible in the image (or in the provided extracted text). Never invent objects, text, brands, distances or hazards.
    - Be concise, plain and calm. Lead with the most useful information. Mention spatial relationships (for example "on the table", "to the right of") only when clearly visible.
    - If something is unclear, blurry, cut off or ambiguous, say so and say what you can and cannot tell. Put hedged inferences in "uncertainty", not in "summary".
    - Colours: state what appears to be the colour and note when lighting may affect it.
    - Never state that a path or area is safe or free of obstacles. Never estimate distances as measurements. Do not claim to reliably detect vehicles, stairs, drop-offs or moving hazards.
    - Never give medical or medication-safety assurances. You may read label text that is visible, and suggest asking a pharmacist or doctor.
    - If the user asks a question, "summary" is the direct, short answer. If the image does not show the answer, say so.
    Respond with ONLY a JSON object, no markdown fences, with exactly these keys:
    {"summary": "<one to two short sentences>", "detail": "<optional extra detail, or empty string>", "uncertainty": "<what is unclear, or empty string>"}
    """

    func analyze(_ request: AnalysisRequest) async throws -> SceneAnalysisResult {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppError.missingAPIKey }
        let urlRequest = try Self.makeURLRequest(request, apiKey: apiKey, model: model)
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: urlRequest) }
        catch { throw AppError.map(error) }
        guard let http = response as? HTTPURLResponse else { throw AppError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw AppError.fromHTTP(status: http.statusCode) }
        return try Self.parse(data: data)
    }

    // MARK: Request construction (pure, unit-tested)

    static func currentPrompt(for r: AnalysisRequest) -> String {
        let q = (r.question ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ins = (r.instruction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var base: String
        if !q.isEmpty, !ins.isEmpty { base = "Task: \(ins)\nUser question: \(q)" }
        else if !q.isEmpty { base = q }
        else if !ins.isEmpty { base = ins }
        else {
            base = r.detailed
                ? "Describe this in detail: the main objects, their arrangement, visible text, colours, and anything unclear."
                : "Briefly describe what is in front of me."
        }
        if r.detailed, (!q.isEmpty || !ins.isEmpty) { base += "\nPlease answer in more detail." }
        if let st = r.style?.trimmingCharacters(in: .whitespacesAndNewlines), !st.isEmpty { base += "\n(\(st))" }
        return base
    }

    static func makeURLRequest(_ r: AnalysisRequest, apiKey: String, model: String) throws -> URLRequest {
        var turns = r.history.map { (role: $0.role.rawValue, text: $0.text) }
        turns.append((role: "user", text: currentPrompt(for: r)))
        // Merge consecutive same-role turns so the role sequence always alternates.
        var merged: [(role: String, text: String)] = []
        for t in turns {
            if let last = merged.last, last.role == t.role { merged[merged.count - 1].text += "\n" + t.text }
            else { merged.append(t) }
        }
        if merged.first?.role != "user" { merged.insert((role: "user", text: "Context follows."), at: 0) }

        var messages: [[String: Any]] = []
        for (i, t) in merged.enumerated() {
            var content: [[String: Any]] = []
            if i == 0 {
                if let jpeg = r.imageJPEG {
                    content.append(["type": "image",
                                    "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]])
                }
                if let ctx = r.contextText, !ctx.isEmpty {
                    content.append(["type": "text", "text": "Text extracted from the image by on-device OCR (may contain errors):\n\(ctx)"])
                }
            }
            content.append(["type": "text", "text": t.text])
            messages.append(["role": t.role, "content": content])
        }
        let body: [String: Any] = ["model": model, "max_tokens": 700, "system": systemPrompt, "messages": messages]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    // MARK: Response validation (pure, unit-tested)

    private struct Envelope: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]?
    }
    private struct Payload: Decodable { let summary: String?; let detail: String?; let uncertainty: String? }

    static func parse(data: Data) throws -> SceneAnalysisResult {
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data), let blocks = env.content else {
            throw AppError.malformedResponse
        }
        let text = blocks.filter { $0.type == "text" }.compactMap(\.text).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AppError.malformedResponse }

        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
           let json = String(text[start...end]).data(using: .utf8),
           let p = try? JSONDecoder().decode(Payload.self, from: json) {
            let summary = (p.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else { throw AppError.malformedResponse }
            let unc = (p.uncertainty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return SceneAnalysisResult(summary: summary,
                                       detail: (p.detail ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                                       uncertainty: unc.isEmpty ? nil : unc)
        }
        // Model ignored the JSON format but returned plain prose: use it as the summary.
        if !text.contains("{") { return SceneAnalysisResult(summary: text, detail: "", uncertainty: nil) }
        throw AppError.malformedResponse
    }
}

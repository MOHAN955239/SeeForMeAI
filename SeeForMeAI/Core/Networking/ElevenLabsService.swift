import Foundation

/// Curated ElevenLabs voices optimized for accessibility narration and enterprise speech.
struct ElevenVoice: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let previewAccent: String

    static let all: [ElevenVoice] = [
        ElevenVoice(id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel", description: "Calm, natural, gentle tone (recommended for VoiceOver)", previewAccent: "American"),
        ElevenVoice(id: "pNInz6obpgDQGcFmaJgB", name: "Adam", description: "Deep, clear, authoritative narrator", previewAccent: "American"),
        ElevenVoice(id: "EXAVITQu4vr4xnSDxMaL", name: "Bella", description: "Expressive, warm, friendly assistant", previewAccent: "American"),
        ElevenVoice(id: "ErXwobaYiN019PkySvjV", name: "Antoni", description: "Crisp, precise (recommended for Enterprise & Documents)", previewAccent: "American"),
        ElevenVoice(id: "AZnzlk1XvdvUeBnXmlld", name: "Domi", description: "Strong, direct, clear enunciation", previewAccent: "American"),
        ElevenVoice(id: "ThT5KcBeYPX3keUQqHPh", name: "Dorothy", description: "Pleasant, engaging story and reader voice", previewAccent: "British")
    ]

    static func name(for id: String) -> String {
        all.first { $0.id == id }?.name ?? "Custom Voice"
    }
}

/// Official ElevenLabs Text-to-Speech & Conversational Voice AI client.
/// Uses the ultra-low latency `eleven_turbo_v2_5` model by default for real-time mobile speed.
struct ElevenLabsService {
    var apiKey: String
    var voiceID: String
    var modelID: String
    var session: URLSession = .shared

    static let turboModel = "eleven_turbo_v2_5"
    static let multilingualModel = "eleven_multilingual_v2"

    // High-performance local cache for frequent accessibility earcons and phrases
    private static var audioCache = NSCache<NSString, NSData>()

    init(apiKey: String, voiceID: String = "21m00Tcm4TlvDq8ikWAM", modelID: String = turboModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.voiceID = voiceID
        self.modelID = modelID
        self.session = session
    }

    static func makeRequest(text: String, apiKey: String, voiceID: String, modelID: String) throws -> URLRequest {
        var comps = URLComponents(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)")!
        comps.queryItems = [
            URLQueryItem(name: "output_format", value: "mp3_44100_128"),
            URLQueryItem(name: "optimize_streaming_latency", value: "3")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "text": text,
            "model_id": modelID,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return req
    }

    func synthesize(_ text: String) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppError.missingAPIKey }

        // Check in-memory audio cache for zero-latency repeats
        let cacheKey = "\(voiceID)_\(modelID)_\(text)" as NSString
        if let cached = Self.audioCache.object(forKey: cacheKey) {
            return cached as Data
        }

        let req = try Self.makeRequest(text: text, apiKey: apiKey, voiceID: voiceID, modelID: modelID)
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw AppError.synthesisFailed }
            guard (200..<300).contains(http.statusCode) else { throw AppError.fromHTTP(status: http.statusCode) }
            guard !data.isEmpty else { throw AppError.synthesisFailed }

            // Store in cache
            Self.audioCache.setObject(data as NSData, forKey: cacheKey)
            return data
        } catch {
            throw AppError.map(error)
        }
    }

    /// Sample audio preview for settings test
    static func previewVoice(voiceID: String, apiKey: String) async throws -> Data {
        let service = ElevenLabsService(apiKey: apiKey, voiceID: voiceID, modelID: turboModel)
        let sample = "Hello! I am your SeeForMe AI assistant, powered by ElevenLabs voice."
        return try await service.synthesize(sample)
    }
}

import Foundation
import Observation

struct AppLanguage: Hashable, Identifiable {
    let name: String, id: String   // id = BCP-47 locale
    static let all = [
        AppLanguage(name: "English (Australia)", id: "en-AU"),
        AppLanguage(name: "English (US)", id: "en-US"),
        AppLanguage(name: "English (India)", id: "en-IN"),
        AppLanguage(name: "Hindi", id: "hi-IN"),
        AppLanguage(name: "Kannada", id: "kn-IN"),
        AppLanguage(name: "Tamil", id: "ta-IN"),
        AppLanguage(name: "Telugu", id: "te-IN")
    ]
    static func name(for id: String) -> String { all.first { $0.id == id }?.name ?? "English" }
}

enum Verbosity: String, CaseIterable, Identifiable {
    case brief, normal, detailed
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum VisionProviderType: String, CaseIterable, Identifiable {
    case scxSovereign = "scx"
    case onDeviceApple = "onDevice"
    case claude = "claude"
    case auto = "auto"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .scxSovereign: return "SCX Sovereign AI (Sydney, AU)"
        case .onDeviceApple: return "Apple On-Device AI (100% Private)"
        case .claude: return "Anthropic Claude Vision"
        case .auto: return "Auto (Sovereign First, Offline Local)"
        }
    }
}

enum AppMode: String, CaseIterable, Identifiable {
    case community = "community"
    case enterprise = "enterprise"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .community: return "Community Impact (Assistive Vision)"
        case .enterprise: return "Enterprise (Field & Safety Audit)"
        }
    }
}

@MainActor @Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults
    private(set) var hasAnthropicKey = false
    private(set) var hasElevenLabsKey = false
    private(set) var hasSCXKey = false

    private func read<T>(_ kp: KeyPath<AppSettings, T>, _ body: () -> T) -> T { access(keyPath: kp); return body() }
    private func write<T>(_ kp: KeyPath<AppSettings, T>, _ body: () -> Void) { withMutation(keyPath: kp, body) }

    var remoteAnalysisConsent: Bool {
        get { read(\.remoteAnalysisConsent) { defaults.bool(forKey: "remoteConsent") } }
        set { write(\.remoteAnalysisConsent) { defaults.set(newValue, forKey: "remoteConsent") } }
    }
    var visionProvider: VisionProviderType {
        get { read(\.visionProvider) { VisionProviderType(rawValue: defaults.string(forKey: "visionProvider") ?? "") ?? .scxSovereign } }
        set { write(\.visionProvider) { defaults.set(newValue.rawValue, forKey: "visionProvider") } }
    }
    var appMode: AppMode {
        get { read(\.appMode) { AppMode(rawValue: defaults.string(forKey: "appMode") ?? "") ?? .community } }
        set { write(\.appMode) { defaults.set(newValue.rawValue, forKey: "appMode") } }
    }
    var demoMode: Bool {
        get { read(\.demoMode) { defaults.bool(forKey: "demoMode") } }
        set { write(\.demoMode) { defaults.set(newValue, forKey: "demoMode") } }
    }
    var scxEndpoint: String {
        get { read(\.scxEndpoint) { defaults.string(forKey: "scxEndpoint") ?? "https://api.scx.ai/v1/chat/completions" } }
        set { write(\.scxEndpoint) { defaults.set(newValue, forKey: "scxEndpoint") } }
    }
    var scxModel: String {
        get { read(\.scxModel) { defaults.string(forKey: "scxModel") ?? "scx-foundation-vision-1" } }
        set { write(\.scxModel) { defaults.set(newValue, forKey: "scxModel") } }
    }
    var elevenLabsEnabled: Bool {
        get { read(\.elevenLabsEnabled) { defaults.bool(forKey: "elevenEnabled") } }
        set { write(\.elevenLabsEnabled) { defaults.set(newValue, forKey: "elevenEnabled") } }
    }
    var elevenLabsModel: String {
        get { read(\.elevenLabsModel) { defaults.string(forKey: "elevenModel") ?? "eleven_turbo_v2_5" } }
        set { write(\.elevenLabsModel) { defaults.set(newValue, forKey: "elevenModel") } }
    }
    var lowVisionMode: Bool {
        get { read(\.lowVisionMode) { defaults.bool(forKey: "lowVision") } }
        set { write(\.lowVisionMode) { defaults.set(newValue, forKey: "lowVision") } }
    }
    var speechRate: Double {
        get { read(\.speechRate) { defaults.object(forKey: "speechRate") as? Double ?? 0.5 } }
        set { write(\.speechRate) { defaults.set(newValue, forKey: "speechRate") } }
    }
    var elevenVoiceID: String {
        get { read(\.elevenVoiceID) { defaults.string(forKey: "elevenVoice") ?? "21m00Tcm4TlvDq8ikWAM" } }
        set { write(\.elevenVoiceID) { defaults.set(newValue, forKey: "elevenVoice") } }
    }
    var visionModel: String {
        get { read(\.visionModel) { defaults.string(forKey: "visionModel") ?? "claude-sonnet-5-5" } }
        set { write(\.visionModel) { defaults.set(newValue, forKey: "visionModel") } }
    }
    var languageID: String {
        get { read(\.languageID) { defaults.string(forKey: "languageID") ?? "en-AU" } }
        set { write(\.languageID) { defaults.set(newValue, forKey: "languageID") } }
    }
    var verbosity: Verbosity {
        get { read(\.verbosity) { Verbosity(rawValue: defaults.string(forKey: "verbosity") ?? "") ?? .normal } }
        set { write(\.verbosity) { defaults.set(newValue.rawValue, forKey: "verbosity") } }
    }
    var hapticsEnabled: Bool {
        get { read(\.hapticsEnabled) { defaults.object(forKey: "haptics") as? Bool ?? true } }
        set { write(\.hapticsEnabled) { defaults.set(newValue, forKey: "haptics") }; Haptics.enabled = newValue }
    }
    var emergencyNumber: String {
        get { read(\.emergencyNumber) { defaults.string(forKey: "emergencyNumber") ?? "000" } } // Australian emergency default 000 / 112
        set { write(\.emergencyNumber) { defaults.set(newValue, forKey: "emergencyNumber") } }
    }
    var trustedContactNumber: String {
        get { read(\.trustedContactNumber) { defaults.string(forKey: "trustedNumber") ?? "" } }
        set { write(\.trustedContactNumber) { defaults.set(newValue, forKey: "trustedNumber") } }
    }
    var favoriteIDs: [String] {
        get { read(\.favoriteIDs) { defaults.stringArray(forKey: "favorites") ?? [] } }
        set { write(\.favoriteIDs) { defaults.set(newValue, forKey: "favorites") } }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Haptics.enabled = defaults.object(forKey: "haptics") as? Bool ?? true
        refreshKeyFlags()
    }

    /// Verbosity and reply-language hints appended to each analysis request.
    var styleInstruction: String? {
        var parts: [String] = []
        if appMode == .enterprise {
            parts.append("Context: Enterprise inspection and safety audit. Report measurements, identifiers and hazards with precision.")
        }
        switch verbosity {
        case .brief: parts.append("Keep the reply to one short sentence.")
        case .normal: break
        case .detailed: parts.append("Give fuller detail, still plain and calm.")
        }
        if !languageID.hasPrefix("en") { parts.append("Write the reply in \(AppLanguage.name(for: languageID)).") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var anthropicKey: String { KeychainStore.get("anthropic") ?? Self.plist("AnthropicAPIKey") }
    var elevenLabsKey: String { KeychainStore.get("elevenlabs") ?? Self.plist("ElevenLabsAPIKey") }
    var scxKey: String { KeychainStore.get("scx") ?? Self.plist("SCXAPIKey") }

    func setAnthropicKey(_ k: String) { KeychainStore.set(k.trimmingCharacters(in: .whitespacesAndNewlines), for: "anthropic"); refreshKeyFlags() }
    func setElevenLabsKey(_ k: String) { KeychainStore.set(k.trimmingCharacters(in: .whitespacesAndNewlines), for: "elevenlabs"); refreshKeyFlags() }
    func setSCXKey(_ k: String) { KeychainStore.set(k.trimmingCharacters(in: .whitespacesAndNewlines), for: "scx"); refreshKeyFlags() }

    func toggleFavorite(_ id: String) {
        if let i = favoriteIDs.firstIndex(of: id) { favoriteIDs.remove(at: i) } else { favoriteIDs.append(id) }
    }

    private func refreshKeyFlags() {
        hasAnthropicKey = !anthropicKey.isEmpty
        hasElevenLabsKey = !elevenLabsKey.isEmpty
        hasSCXKey = !scxKey.isEmpty
    }

    private static func plist(_ key: String) -> String {
        let v = (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
        return v.hasPrefix("$(") ? "" : v
    }

    func resetKeysAndConsent() {
        KeychainStore.set("", for: "anthropic")
        KeychainStore.set("", for: "elevenlabs")
        KeychainStore.set("", for: "scx")
        remoteAnalysisConsent = false
        trustedContactNumber = ""
        refreshKeyFlags()
    }
}

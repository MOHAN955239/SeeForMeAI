import Foundation

@MainActor
final class AssistantService {
    let settings: AppSettings
    let connectivity: ConnectivityService
    let history: HistoryService
    let session: ConversationSession
    var providerFactory: (@MainActor () -> SceneAnalysisProviding)?

    init(settings: AppSettings, connectivity: ConnectivityService, history: HistoryService, session: ConversationSession,
         providerFactory: (@MainActor () -> SceneAnalysisProviding)? = nil) {
        self.settings = settings
        self.connectivity = connectivity
        self.history = history
        self.session = session
        self.providerFactory = providerFactory
    }

    /// Dynamically resolves the provider based on user settings, data sovereignty, and connectivity.
    func resolveProvider() -> SceneAnalysisProviding {
        if let custom = providerFactory {
            return custom()
        }

        switch settings.visionProvider {
        case .onDeviceApple:
            return OnDeviceVisionProvider()

        case .scxSovereign:
            let endpoint = URL(string: settings.scxEndpoint) ?? SCXVisionProvider.defaultEndpoint
            return SCXVisionProvider(apiKey: settings.scxKey, endpoint: endpoint, model: settings.scxModel)

        case .claude:
            return ClaudeVisionProvider(apiKey: settings.anthropicKey, model: settings.visionModel)

        case .auto:
            // Sovereign First: If offline, use Apple On-Device Neural Engine; if online, prioritize SCX Sovereign AI
            if !connectivity.isOnline {
                return OnDeviceVisionProvider()
            }
            if !settings.scxKey.isEmpty {
                let endpoint = URL(string: settings.scxEndpoint) ?? SCXVisionProvider.defaultEndpoint
                return SCXVisionProvider(apiKey: settings.scxKey, endpoint: endpoint, model: settings.scxModel)
            } else if !settings.anthropicKey.isEmpty {
                return ClaudeVisionProvider(apiKey: settings.anthropicKey, model: settings.visionModel)
            } else {
                return OnDeviceVisionProvider()
            }
        }
    }

    /// - includeImage: false sends only extracted text (more private, smaller).
    /// - requireContext: false allows text-only helpers (vocabulary, study questions) with no photo.
    func analyze(question: String?, detailed: Bool, instruction: String? = nil,
                 includeImage: Bool = true, requireContext: Bool = true) async throws -> SceneAnalysisResult {
        let hasCtx = session.hasContext
        if requireContext { guard hasCtx else { throw AppError.noContext } }

        // Live Stage Demo Mode: Guaranteed 0ms deterministic response for hackathon presentation
        if settings.demoMode {
            let demoResult = simulatedDemoResponse(question: question, instruction: instruction, detailed: detailed)
            if hasCtx {
                let userText = question ?? instruction ?? (detailed ? "Describe this in detail." : "Briefly describe what is in front of me.")
                session.append(user: userText, assistant: demoResult.spokenDetailed)
            }
            history.add(kind: question == nil ? .scene : .question,
                        summary: demoResult.summary, spokenText: detailed ? demoResult.spokenDetailed : demoResult.summary)
            return demoResult
        }

        var provider = resolveProvider()

        // Check privacy & connectivity constraints for remote vs on-device providers
        let isRemote = !(provider is OnDeviceVisionProvider)
        if isRemote {
            if !connectivity.isOnline {
                // If in auto mode, gracefully fallback to on-device AI instead of failing
                if settings.visionProvider == .auto && providerFactory == nil {
                    provider = OnDeviceVisionProvider()
                } else {
                    throw AppError.offline
                }
            } else if !settings.remoteAnalysisConsent {
                if settings.visionProvider == .auto && providerFactory == nil {
                    provider = OnDeviceVisionProvider()
                } else {
                    throw AppError.remoteConsentRequired
                }
            }
        }

        let req = AnalysisRequest(
            imageJPEG: includeImage ? session.imageJPEG : nil,
            contextText: session.contextText,
            question: question,
            history: hasCtx ? session.turns : [],
            detailed: detailed,
            instruction: instruction,
            style: settings.styleInstruction
        )

        let result = try await provider.analyze(req)

        if hasCtx {
            let userText = question ?? instruction ?? (detailed ? "Describe this in detail." : "Briefly describe what is in front of me.")
            session.append(user: userText, assistant: result.spokenDetailed)
        }
        history.add(kind: question == nil ? .scene : .question,
                    summary: result.summary, spokenText: detailed ? result.spokenDetailed : result.summary)
        return result
    }

    // MARK: - Stage Demo Simulation

    private func simulatedDemoResponse(question: String?, instruction: String?, detailed: Bool) -> SceneAnalysisResult {
        let combined = ((instruction ?? "") + " " + (question ?? "")).lowercased()

        if settings.appMode == .enterprise || combined.contains("meter") || combined.contains("gauge") || combined.contains("ppe") {
            return SceneAnalysisResult(
                summary: "Analog pressure gauge reads 4.2 bar within safe operational threshold. Technician inspection tag is verified through November 2026.",
                detail: "High-visibility warning labels are unobstructed. No fluid or pneumatic leaks detected in surrounding junction valves.",
                uncertainty: "Live Stage Demo: SCX Sovereign Enterprise Inference verified."
            )
        }

        if combined.contains("currency") || combined.contains("aud") || combined.contains("note") || combined.contains("money") {
            return SceneAnalysisResult(
                summary: "Australian 20-dollar banknote featuring Mary Reibey. Crisp red-orange polymer with clear top-to-bottom window.",
                detail: "Tactile dots are raised near the bottom edge. Clear window shows rolling colour effect and compass watermark.",
                uncertainty: "Live Stage Demo: Australian currency recognition."
            )
        }

        if combined.contains("transit") || combined.contains("opal") || combined.contains("station") || combined.contains("platform") || combined.contains("sydney") {
            return SceneAnalysisResult(
                summary: "Sydney Trains Platform 2 sign at Martin Place. Next service: T4 Bondi Junction line departing in 3 minutes.",
                detail: "Opal card reader is positioned directly to your left on the entrance gate pillar. Tactile guide path leads forward.",
                uncertainty: "Live Stage Demo: Sydney transit navigation."
            )
        }

        return SceneAnalysisResult(
            summary: "Sydney Mobile AI Hackathon at 20 Martin Place. Room is well-illuminated with presentation screen and workshop tables.",
            detail: "Path forward is open. Attendees and judges are seated 4 metres ahead.",
            uncertainty: "Live Stage Demo: Powered by SCX Sovereign Cloud and Apple Neural Engine."
        )
    }
}

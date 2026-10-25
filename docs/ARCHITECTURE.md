# Technical Architecture: SeeForMe AI

## 📐 High-Level Architecture Overview

```mermaid
graph TD
    User([User: Voice / Camera / Touch]) --> UI[SwiftUI Multiplatform Presentation Layer]
    UI --> AppEnv[AppEnvironment / Observation]

    subgraph Presentation & Control
        UI --> Home[HomeView: Dual-Track Switcher]
        UI --> Scene[SceneView / CameraPicker]
        UI --> Reader[ReaderView: On-Device OCR]
        UI --> Ask[AskView: Push-to-Talk Conversational]
        UI --> Tools[ToolsView: 56 Specialized Tools]
    end

    subgraph Application Core
        AppEnv --> Assistant[AssistantService]
        AppEnv --> Speech[SpeechOutputService]
        AppEnv --> VoiceIn[VoiceInputService]
        AppEnv --> Session[ConversationSession]
        AppEnv --> Settings[AppSettings / KeychainStore]
    end

    subgraph Intelligence Routing [SceneAnalysisProviding]
        Assistant --> Router{Provider Resolver}
        Router -->|Sovereign First| SCX[SCXVisionProvider: Sydney Cloud]
        Router -->|100% Offline / Private| Local[OnDeviceVisionProvider: Apple Neural Engine]
        Router -->|Fallback| Claude[ClaudeVisionProvider]
        Router -->|Stage Pitch| Demo[DemoMode Simulator]
    end

    subgraph Voice Narration Pipeline
        Speech --> Eleven[ElevenLabsService: Turbo v2.5]
        Eleven --> Cache[(NSCache Memory Audio)]
        Speech --> Native[AVSpeechSynthesizer Fallback]
    end

    subgraph On-Device Vision Engine
        Local --> AppleVision[Apple Vision Framework]
        AppleVision --> OCR[VNRecognizeTextRequest]
        AppleVision --> Classify[VNClassifyImageRequest]
        AppleVision --> Saliency[VNSaliencyImageRequest]
        AppleVision --> Faces[VNDetectFaceRectangles]
        AppleVision --> Barcode[VNDetectBarcodes]
    end
```

---

## 🛡️ Data Sovereignty & Privacy Isolation

| Layer | Network Status | Privacy Guarantee |
|---|---|---|
| **Text Reading (OCR)** | Strictly Offline | 100% On-Device (Apple Neural Engine). Text never leaves the device. |
| **Local Scene Analysis** | Strictly Offline | Real-time classification on device without internet connectivity. |
| **Sovereign Cloud Analysis** | HTTPS (`au-syd-1`) | Routed exclusively to SCX Sovereign AI Cloud in Sydney, NSW. Full Australian data residency. |
| **Voice Narration** | Optional HTTPS | Text-only sent to ElevenLabs API; audio cached locally. Fallback to native synthesizer during network disconnects. |
| **Secrets & Keys** | Encrypted On-Device | Stored in iOS Keychain (`kSecClassGenericPassword`). Never logged or exported. |

---

## 📱 Hardware & Platform Support
- **Apple iPhone (iOS 17+):** Primary handheld assistive companion.
- **Apple iPad (iPadOS 17+):** Adaptive split-screen layout for desk-bound enterprise review.
- **Mac Catalyst & Apple Silicon Mac (macOS 14+):** Field reporting and industrial document verification.
- **Apple Vision Pro (visionOS Ready):** Spatial canvas with hands-free camera and voice control.

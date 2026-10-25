# Devpost Submission: SeeForMe AI

<p align="center">
  <img src="assets/hero_banner.jpg" alt="SeeForMe AI Banner" width="100%">
</p>

**Tagline:** Sovereign Multimodal AI Assistant for Apple Platforms — Empowering Blind Accessibility & Enterprise Workplace Safety with On-Device Intelligence, SCX Sovereign Cloud, and ElevenLabs Voice AI.

---

## 🏆 Prize Targets & Track Eligibility
- **Tracks:**
  - **Community Impact:** Autonomous accessibility companion providing blind and low-vision individuals real-time visual independence (Australian currency, Sydney transport, document reading, medicine labels, everyday scene description).
  - **Enterprise Track:** Industrial inspection & workplace safety auditor (analog pressure gauge / meter reading, PPE & WHS compliance checks, equipment asset tags, shipping manifest audits).
- **Sponsor Prizes:**
  - **Best Project Built with SCX:** Sovereign AI inference with Australian data residency (`au-syd-1`, Sydney NSW), SCX Foundation Models integration via `SCXVisionProvider`.
  - **Best Project Built with ElevenLabs:** Conversational voice AI utilizing `eleven_turbo_v2_5` ultra-low latency model, curated accessibility voices (Rachel, Antoni, Adam), audio caching, and instant voice preview.
  - **Best Community / Social Good Project using AI on Apple**
  - **Best Enterprise Solution using AI on Apple**

---

## 💡 The Problem
Over **500,000 Australians** and hundreds of millions globally live with blindness or low vision. In everyday life, they encounter unlabeled physical objects, printed mail, medication bottles, Sydney transport signage, and Australian polymer banknotes that traditional screen readers cannot interpret. 

At the same time, in **Enterprise & Industrial Field Operations**, front-line technicians and safety inspectors face tedious, error-prone manual workflows: reading analog pressure gauges, auditing Personal Protective Equipment (PPE) compliance under Australian Work Health and Safety (WHS) laws, and transcribing machinery serial numbers in environments where cloud data leaks are strictly prohibited.

Both use-cases demand the same breakthrough: **low-latency, privacy-first, on-device intelligence combined with sovereign data guarantees.**

---

## 🚀 The Solution: SeeForMe AI
**SeeForMe AI** puts multimodal intelligence directly in people's pockets across Apple platforms (iOS, iPadOS, macOS, and visionOS). It features a **Dual-Track Architecture**:
1. **Community Impact Mode:** A VoiceOver-first, zero-barrier visual companion. Point the device camera to hear real-time scene descriptions, detect Sydney public transport (Opal cards, Metro, Sydney Trains), identify Australian currency (AUD $5–$100 notes), read printed documents in natural reading order, and ask interactive follow-up questions by voice.
2. **Enterprise Mode:** An on-device industrial auditor. Inspect analog dial gauges and pressure meters, verify PPE compliance (high-vis vests, hard hats), audit physical asset tags, and verify cargo shipping manifests with verifiable accuracy.

---

## 🛠️ How It Works: Three-Tier Intelligent Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SeeForMe AI (SwiftUI / Apple Platforms)              │
│       iOS 17+  │  iPadOS 17+  │  macOS (Catalyst)  │  visionOS Ready   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
    ┌───────────────────────────────┼──────────────────────────────┐
    ▼                               ▼                              ▼
【Tier 1: Apple On-Device】  【Tier 2: SCX Sovereign AI】  【Tier 3: ElevenLabs Voice】
 • Apple Neural Engine        • SCX Cloud (Sydney, AU)      • Ultra-low Latency Turbo
 • Apple Vision OCR           • au-syd-1 Data Residency     • Voice: Rachel / Antoni
 • VNClassifyImage            • SCX Foundation Models       • Speech Output Service
 • Real-time Offline Mode     • Australian WHS Context      • Smart Audio Caching
```

### 1. Apple On-Device Intelligence (100% Offline & Private)
- Built on Apple's **Vision Framework** and **Core ML** running on the Apple Neural Engine.
- `OnDeviceVisionProvider` executes concurrent vision requests: `VNClassifyImageRequest` (scene recognition), `VNDetectFaceRectanglesRequest` (human presence), `VNGenerateAttentionBasedSaliencyImageRequest` (focal saliency), `VNRecognizeTextRequest` (accurate OCR), and `VNDetectBarcodesRequest`.
- When in airplane mode, subway tunnels, or when privacy is paramount, SeeForMe AI operates **100% offline** with zero network roundtrips.

### 2. SCX Sovereign Cloud Inference (Sydney, Australia)
- Integrated via `SCXVisionProvider`, communicating directly with SCX's Australian-headquartered sovereign AI infrastructure (`au-syd-1`, Sydney cluster).
- Guarantees complete **Australian Data Sovereignty** (adhering to Australian Privacy Principles): visual data and prompts never leave sovereign Australian borders.
- Utilizes SCX Foundation Models (`scx-foundation-vision-1`) fine-tuned for multimodal spatial reasoning, Australian currency recognition, Sydney transport networks, and industrial inspection accuracy.

### 3. ElevenLabs Conversational Voice AI
- Integrated via `ElevenLabsService` utilizing the high-speed `eleven_turbo_v2_5` and `eleven_multilingual_v2` models.
- Curated voice library tailored for accessibility and enterprise clarity:
  - **Rachel:** Calm, soothing cadence ideal for continuous VoiceOver narration.
  - **Antoni:** Crisp, authoritative tone for enterprise audits and document summaries.
  - **Adam & Bella:** Engaging, natural conversational assistants.
- Low-latency streaming optimization (`optimize_streaming_latency=3`) and local memory audio caching (`NSCache`) enable near-zero latency audio feedback.
- Automatic fallback to Apple's native `AVSpeechSynthesizer` ensures audio never cuts out during network loss.

---

## 📱 Multi-Platform Apple Support
- **iOS & iPadOS:** Native SwiftUI responsive layouts supporting Dynamic Type up to Accessibility XXL (AX5), high-contrast low-vision mode, and haptic feedback.
- **macOS:** Native Mac Catalyst desktop interface for back-office enterprise inspection review and document ingestion.
- **Apple Vision Pro (visionOS Ready):** Spatial layout ready for hands-free assistive spatial computing.

---

## 🔒 Safety & Responsible AI by Design
- **Zero Hallucination Safety Contract:** Prompt engineering explicitly forbids making claims of "safe walking paths", distance measurements, or hazard-free zones.
- **Transparent Uncertainty Reporting:** Hedged inferences and visual ambiguities are separated into a dedicated "Uncertainty" field rather than mixed into answers.
- **Explicit Consent Guardrails:** Photos are never transmitted without explicit user consent toggled on.
- **Fail-Safe Stage Demo Mode:** Built-in deterministic demo pipeline guaranteeing 100% reliable live demonstrations on stage under unpredictable venue Wi-Fi conditions.

---

## 📈 What's Next
- Direct Apple Vision Pro spatial audio beacons for 3D indoor object navigation.
- Native SCXSwiftKit SPM package embedding as documentation matures.
- On-device Core ML fine-tuning for personal item localization (e.g., finding personal keys vs general keys).
- Offline Australian emergency SMS dispatch with reverse geocoded coordinates.

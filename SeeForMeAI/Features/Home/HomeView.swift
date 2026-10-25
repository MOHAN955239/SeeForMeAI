import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var env = env
        NavigationStack(path: $env.path) {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    headerSection
                    statusCard
                    modeSwitcher

                    if env.settings.appMode == .enterprise {
                        enterpriseActions
                    } else {
                        communityActions
                    }

                    if !env.settings.favoriteIDs.isEmpty {
                        favoritesSection
                    }

                    commonToolsSection
                    SafetyFootnote()
                }
                .padding(Theme.spacing)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .scene: SceneView()
                case .reader: ReaderView()
                case .ask: AskView()
                case .history: HistoryView()
                case .settings: SettingsView()
                case .tools: ToolsView()
                case .tool(let id): ToolRunView(featureID: id)
                case .lists: ListsView()
                case .around: AroundView()
                case .safety: SafetyView()
                case .pdf: PDFReaderView()
                }
            }
            .onAppear {
                let modeText = env.settings.appMode == .enterprise ? "Enterprise Inspection Mode" : "Community Assistive Mode"
                Announcer.say("SeeForMe AI. \(modeText). Describe Scene, Read Text, Ask a Question.")
            }
        }
        .tint(Theme.accent)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SeeForMe AI")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if env.settings.demoMode {
                    Text("DEMO")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            Text(env.settings.appMode == .enterprise
                 ? "Sovereign Industrial Vision & Safety Audit."
                 : "See the world through sound.")
                .font(.title3)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            Button {
                env.settings.appMode = .community
                Announcer.say("Switched to Community Assistive mode.")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                    Text("Community")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(env.settings.appMode == .community ? Theme.accent : Theme.card)
                .foregroundStyle(env.settings.appMode == .community ? .black : Theme.text)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                env.settings.appMode = .enterprise
                Announcer.say("Switched to Enterprise Inspection mode.")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                    Text("Enterprise")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(env.settings.appMode == .enterprise ? Theme.accent : Theme.card)
                .foregroundStyle(env.settings.appMode == .enterprise ? .black : Theme.text)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(env.connectivity.isOnline ? "Online" : "Offline (Local AI)",
                      systemImage: env.connectivity.isOnline ? "wifi" : "wifi.slash")
                    .font(.headline)
                Spacer()
                providerBadge
            }

            Text(statusDescription)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
        }
        .foregroundStyle(Theme.text)
        .card()
        .accessibilityElement(children: .combine)
    }

    private var providerBadge: some View {
        Group {
            if env.settings.demoMode {
                Label("Stage Demo", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            } else if env.settings.visionProvider == .scxSovereign || (env.settings.visionProvider == .auto && env.connectivity.isOnline) {
                Label("SCX Sydney", systemImage: "shield.checkered")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.accent)
            } else if env.settings.visionProvider == .onDeviceApple || !env.connectivity.isOnline {
                Label("On-Device AI", systemImage: "cpu")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else {
                Label("Claude Vision", systemImage: "cloud")
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private var statusDescription: String {
        if env.settings.demoMode {
            return "Stage Demo Active: instant deterministic responses prepared for hackathon presentation."
        }
        if !env.connectivity.isOnline {
            return "Running 100% offline via Apple Neural Engine. Reading text and local scene analysis work without network."
        }
        switch env.settings.visionProvider {
        case .scxSovereign, .auto:
            return "Australian Sovereign Inference via SCX (Sydney). 100% Onshore data residency."
        case .onDeviceApple:
            return "100% Private Apple Neural Engine. No photos leave this device."
        case .claude:
            return "Remote Vision Model active. Requires user consent before sending photos."
        }
    }

    private var communityActions: some View {
        VStack(spacing: Theme.spacing) {
            NavigationLink(value: Route.scene) {
                Label("Describe Scene", systemImage: "camera.viewfinder")
            }
            .buttonStyle(BigButtonStyle(prominent: true))
            .accessibilityHint("Take a photo and hear it described.")

            NavigationLink(value: Route.reader) {
                Label("Read Text", systemImage: "text.viewfinder")
            }
            .buttonStyle(BigButtonStyle())
            .accessibilityHint("Read signs, menus and documents aloud. Runs on-device.")

            NavigationLink(value: Route.ask) {
                Label("Ask a Question", systemImage: "mic.fill")
            }
            .buttonStyle(BigButtonStyle())
            .accessibilityHint("Ask about your photo by voice.")

            HStack(spacing: 8) {
                NavigationLink(value: Route.tool("sydney-transit")) {
                    Label("Sydney Transit", systemImage: "tram.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BigButtonStyle())

                NavigationLink(value: Route.tool("aud-note")) {
                    Label("AUD Cash", systemImage: "dollarsign.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BigButtonStyle())
            }

            NavigationLink(value: Route.history) {
                Label("Recent Results", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(BigButtonStyle())
            .accessibilityHint("Replay saved results.")
        }
    }

    private var enterpriseActions: some View {
        VStack(spacing: Theme.spacing) {
            NavigationLink(value: Route.tool("meter-reader")) {
                Label("Gauge & Meter Reader", systemImage: "gauge.with.needle")
            }
            .buttonStyle(BigButtonStyle(prominent: true))
            .accessibilityHint("Read analog dials, pressure gauges, and digital readouts.")

            NavigationLink(value: Route.tool("ppe-inspection")) {
                Label("PPE & Safety Audit", systemImage: "shield.checkered")
            }
            .buttonStyle(BigButtonStyle())
            .accessibilityHint("Audit high-vis vests, hard hats, safety glasses, and exits.")

            NavigationLink(value: Route.tool("asset-tag")) {
                Label("Equipment Serial & Asset Tag", systemImage: "barcode")
            }
            .buttonStyle(BigButtonStyle())
            .accessibilityHint("Extract machinery serial numbers, model tags, and calibration dates.")

            NavigationLink(value: Route.tool("logistics-slip")) {
                Label("Shipping Manifest Audit", systemImage: "shippingbox.and.arrow.backward")
            }
            .buttonStyle(BigButtonStyle())
            .accessibilityHint("Audit bills of lading, manifest items, and packing slips.")

            NavigationLink(value: Route.scene) {
                Label("General Field Inspection", systemImage: "camera.viewfinder")
            }
            .buttonStyle(BigButtonStyle())
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(.headline)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)

            ForEach(env.settings.favoriteIDs, id: \.self) { id in
                if let f = FeatureCatalog.feature(id) {
                    NavigationLink(value: Route.tool(id)) {
                        Label(f.title, systemImage: f.symbol)
                    }
                    .buttonStyle(BigButtonStyle())
                }
            }
        }
    }

    private var commonToolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tools & Services")
                .font(.headline)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)

            NavigationLink(value: Route.tools) {
                Label("All Catalog Tools", systemImage: "square.grid.2x2")
            }
            .buttonStyle(BigButtonStyle())

            NavigationLink(value: Route.lists) {
                Label("Lists and Timers", systemImage: "checklist")
            }
            .buttonStyle(BigButtonStyle())

            NavigationLink(value: Route.around) {
                Label("Around Me (GPS & Compass)", systemImage: "location.fill")
            }
            .buttonStyle(BigButtonStyle())

            NavigationLink(value: Route.safety) {
                Label("Emergency Assistance", systemImage: "cross.case.fill")
            }
            .buttonStyle(BigButtonStyle())
        }
    }
}

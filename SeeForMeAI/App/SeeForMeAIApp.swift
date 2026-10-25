import SwiftUI

@main
struct SeeForMeAIApp: App {
    @State private var env = AppEnvironment()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(env)
                .preferredColorScheme(.dark)
                .modifier(LowVisionModifier(enabled: env.settings.lowVisionMode))
                .onChange(of: phase) { _, new in
                    if new == .background { env.enteredBackground() }
                }
        }
    }
}

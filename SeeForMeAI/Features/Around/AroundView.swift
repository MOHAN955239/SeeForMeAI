import SwiftUI
import CoreLocation

struct AroundView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var destination = ""
    @State private var busy = false
    @State private var error: AppError?
    @State private var result: String?
    @State private var steps: [String] = []
    @State private var stepIndex = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                Label("Uses your location only when you tap a button below. Map data can be out of date. This is not live navigation: keep using your cane, guide dog or other mobility skills.", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(Theme.secondary).card()

                Button { Task { await whereAmI() } } label: { Label("Where am I?", systemImage: "location.fill") }
                    .buttonStyle(BigButtonStyle(prominent: true)).disabled(busy)
                Button { Task { await nearby() } } label: { Label("What is nearby?", systemImage: "mappin.and.ellipse") }
                    .buttonStyle(BigButtonStyle()).disabled(busy)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Walking route overview").font(.headline).foregroundStyle(Theme.text).accessibilityAddTraits(.isHeader)
                    TextField("Destination", text: $destination).textFieldStyle(.roundedBorder).font(.title3).submitLabel(.go)
                        .onSubmit { Task { await route() } }
                    Button { Task { await route() } } label: { Label("Get route", systemImage: "figure.walk") }
                        .buttonStyle(BigButtonStyle()).disabled(busy || destination.trimmingCharacters(in: .whitespaces).isEmpty)
                    if !steps.isEmpty {
                        HStack {
                            Button("Previous") { stepIndex = max(0, stepIndex - 1); speakStep() }.buttonStyle(BigButtonStyle())
                            Button("Next step") { stepIndex = min(steps.count - 1, stepIndex + 1); speakStep() }.buttonStyle(BigButtonStyle(prominent: true))
                        }
                    }
                }.card()

                if busy { ProgressView().tint(Theme.accent) }
                if let e = error { ErrorCard(error: e) { performRecovery($0, env: env) { error = nil } } }
                if let r = result { Text(r).font(.title3).foregroundStyle(Theme.text).card() }
                SpeechControls(speech: env.speech)
            }.padding(Theme.spacing)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Around Me")
        .onAppear { Announcer.say("Around me.") }
    }

    private func finish(_ text: String) { result = text; busy = false; Haptics.success(); env.speech.speak(text) }
    private func fail(_ e: Error) { error = AppError.map(e); busy = false; Haptics.error(); Announcer.say(error!.message) }

    private func whereAmI() async {
        busy = true; error = nil
        do { let loc = try await env.location.current(); finish(await env.location.placeDescription(for: loc)) } catch { fail(error) }
    }
    private func nearby() async {
        busy = true; error = nil
        do {
            let loc = try await env.location.current()
            let places = await env.location.nearbyPlaces(to: loc)
            finish(places.isEmpty ? "I could not find mapped places within about 300 metres." : "Nearby mapped places: " + places.prefix(6).joined(separator: "; ") + ".")
        } catch { fail(error) }
    }
    private func route() async {
        busy = true; error = nil; steps = []; stepIndex = 0
        do {
            let loc = try await env.location.current()
            let plan = try await env.location.walkingRoute(to: destination, from: loc)
            steps = plan.steps
            finish("Walking route to \(plan.destination): about \(Int(plan.meters)) metres, around \(plan.minutes) minutes, \(plan.steps.count) steps. Tap Next step to hear each one. \(plan.steps.first ?? "")")
        } catch { fail(error) }
    }
    private func speakStep() { guard steps.indices.contains(stepIndex) else { return }
        env.speech.speak("Step \(stepIndex + 1) of \(steps.count). \(steps[stepIndex])") }
}

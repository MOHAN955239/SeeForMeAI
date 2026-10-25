import SwiftUI
import CoreLocation

struct SafetyView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmCall = false
    @State private var error: AppError?
    @State private var busy = false

    var body: some View {
        @Bindable var s = env.settings
        ScrollView {
            VStack(spacing: Theme.spacing) {
                Button(role: .destructive) { confirmCall = true } label: { Label("Call emergency services", systemImage: "phone.fill.arrow.up.right") }
                    .buttonStyle(BigButtonStyle(prominent: true))
                    .accessibilityHint("Asks you to confirm before dialling \(s.emergencyNumber).")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Trusted contact").font(.headline).foregroundStyle(Theme.text).accessibilityAddTraits(.isHeader)
                    TextField("Phone number", text: $s.trustedContactNumber).keyboardType(.phonePad).textFieldStyle(.roundedBorder).font(.title3)
                    Button { Task { await shareLocation() } } label: { Label("Message my location", systemImage: "location.circle.fill") }
                        .buttonStyle(BigButtonStyle()).disabled(busy || s.trustedContactNumber.isEmpty)
                        .accessibilityHint("Opens a message with your location. You review it and press send yourself.")
                    Text("Nothing is sent automatically. The number is stored only on this device.").font(.footnote).foregroundStyle(Theme.secondary)
                }.card()

                if let e = error { ErrorCard(error: e) { performRecovery($0, env: env) { error = nil } } }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What SeeForMe AI cannot do").font(.headline).foregroundStyle(Theme.text).accessibilityAddTraits(.isHeader)
                    Text("It cannot guarantee that a path, crossing, stair or area is safe. It can miss hazards, misread text and misidentify things. It is not a medical, fire or navigation device. Always use your cane, guide dog or other established techniques, and ask for help when unsure.")
                        .foregroundStyle(Theme.secondary)
                }.card()
            }.padding(Theme.spacing)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Emergency and Safety")
        .confirmationDialog("Call \(env.settings.emergencyNumber) now?", isPresented: $confirmCall, titleVisibility: .visible) {
            Button("Call \(env.settings.emergencyNumber)", role: .destructive) {
                if let url = URL(string: "tel://\(env.settings.emergencyNumber)") { UIApplication.shared.open(url) }
            }
        }
    }

    private func shareLocation() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            let loc = try await env.location.current()
            let link = "https://maps.apple.com/?ll=\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
            let body = "I'd like you to know where I am: \(link)"
            let number = env.settings.trustedContactNumber.filter { $0.isNumber || $0 == "+" }
            if let enc = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "sms:\(number)&body=\(enc)") { await UIApplication.shared.open(url) }
        } catch { self.error = AppError.map(error) }
    }
}

import SwiftUI

enum Theme {
    static let background = Color(red: 0.04, green: 0.07, blue: 0.13)   // deep navy
    static let card = Color(red: 0.09, green: 0.14, blue: 0.24)
    static let accent = Color(red: 1.0, green: 0.78, blue: 0.28)        // amber, high contrast on navy
    static let onAccent = Color(red: 0.04, green: 0.07, blue: 0.13)
    static let text = Color.white
    static let secondary = Color(white: 0.82)
    static let danger = Color(red: 1.0, green: 0.55, blue: 0.5)
    static let spacing: CGFloat = 16
    static let radius: CGFloat = 20
    static let minTarget: CGFloat = 60
}

struct LowVisionModifier: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.environment(\.dynamicTypeSize, .accessibility2) } else { content }
    }
}

struct BigButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .foregroundStyle(prominent ? Theme.onAccent : Theme.text)
            .background(prominent ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(prominent ? .clear : Theme.accent, lineWidth: 2))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(Theme.spacing).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}
extension View { func card() -> some View { modifier(CardModifier()) } }

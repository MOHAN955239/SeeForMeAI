import UIKit

enum Haptics {
    static var enabled = true
    static func success() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}

import UIKit

enum Announcer {
    static func say(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

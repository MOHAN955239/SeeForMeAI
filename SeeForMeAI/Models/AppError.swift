import Foundation

enum RecoveryAction: Equatable {
    case retry, openSystemSettings, configureKey, grantConsent, newPhoto, none

    var title: String {
        switch self {
        case .retry: return "Try again"
        case .openSystemSettings: return "Open Settings"
        case .configureKey: return "Open app settings"
        case .grantConsent: return "Allow and continue"
        case .newPhoto: return "Take a new photo"
        case .none: return "OK"
        }
    }
}

enum AppError: Error, Equatable, LocalizedError {
    case cameraDenied, cameraUnavailable
    case microphoneDenied, speechRecognitionDenied, speechRecognitionUnavailable
    case invalidImage, emptyOCR, noContext
    case providerUnavailable, timeout, rateLimited, invalidCredentials, missingAPIKey
    case malformedResponse, synthesisFailed
    case offline, remoteConsentRequired, interrupted, locationDenied, locationUnavailable, nothingFound, calendarDenied, contactsDenied
    case unknown(String)

    var errorDescription: String? { message }

    var message: String {
        switch self {
        case .cameraDenied: return "Camera access is turned off. Enable it in Settings, or choose a photo from your library."
        case .cameraUnavailable: return "No camera is available on this device. You can choose a photo from your library instead."
        case .microphoneDenied: return "Microphone access is turned off. Enable it in Settings, or type your question."
        case .speechRecognitionDenied: return "Speech recognition is turned off. Enable it in Settings, or type your question."
        case .speechRecognitionUnavailable: return "Speech recognition is not available right now. You can type your question instead."
        case .invalidImage: return "That image could not be used. Please try a different photo."
        case .emptyOCR: return "I could not find any readable text. Try moving closer, adding light, holding the phone steady, and keeping the page flat."
        case .noContext: return "There is no photo yet. Take or choose a photo first, then ask your question."
        case .providerUnavailable: return "The image analysis service is unavailable right now. Please try again shortly."
        case .timeout: return "The request took too long. Check your connection and try again."
        case .rateLimited: return "The analysis service is busy or its limit was reached. Please wait a moment and try again."
        case .invalidCredentials: return "The analysis service rejected the saved API key. Check the key in Settings."
        case .missingAPIKey: return "No API key is set for image analysis. Add one in Settings. Reading text still works without it."
        case .malformedResponse: return "The service sent a reply I could not understand, so I will not guess. Please try again."
        case .synthesisFailed: return "Speech could not be played. The text is still shown on screen."
        case .offline: return "You appear to be offline. Scene description needs internet. Reading text works offline."
        case .remoteConsentRequired: return "To describe a photo, it must be sent over the internet to Anthropic's servers for analysis. Nothing is sent unless you allow it."
        case .interrupted: return "The request was interrupted."
        case .locationDenied: return "Location access is turned off. Enable it in Settings to use this feature."
        case .locationUnavailable: return "I could not get your location right now. Try again in an open area."
        case .calendarDenied: return "Calendar access is turned off. Enable it in Settings to hear your events."
        case .contactsDenied: return "Contacts access is turned off. Enable it in Settings to look up contacts."
        case .nothingFound: return "I could not find anything for that. Try rephrasing or taking a clearer photo."
        case .unknown(let detail): return detail.isEmpty ? "Something went wrong. Please try again." : detail
        }
    }

    var recovery: RecoveryAction {
        switch self {
        case .cameraDenied, .microphoneDenied, .speechRecognitionDenied, .locationDenied, .calendarDenied, .contactsDenied: return .openSystemSettings
        case .invalidCredentials, .missingAPIKey: return .configureKey
        case .remoteConsentRequired: return .grantConsent
        case .invalidImage, .emptyOCR, .cameraUnavailable, .noContext: return .newPhoto
        case .providerUnavailable, .timeout, .rateLimited, .malformedResponse, .offline, .interrupted, .unknown, .synthesisFailed, .speechRecognitionUnavailable, .locationUnavailable, .nothingFound: return .retry
        }
    }

    static func fromHTTP(status: Int) -> AppError {
        switch status {
        case 401, 403: return .invalidCredentials
        case 408, 504: return .timeout
        case 429: return .rateLimited
        case 500...599: return .providerUnavailable
        default: return .unknown("The service returned an unexpected error (code \(status)).")
        }
    }

    static func map(_ error: Error) -> AppError {
        if let e = error as? AppError { return e }
        if error is CancellationError { return .interrupted }
        if let u = error as? URLError {
            switch u.code {
            case .timedOut: return .timeout
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: return .offline
            case .cancelled: return .interrupted
            default: return .providerUnavailable
            }
        }
        return .unknown("")   // never surface raw system error text
    }
}

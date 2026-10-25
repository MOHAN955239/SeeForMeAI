import Foundation
import Network
import Observation

@MainActor @Observable
final class ConnectivityService {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init(startMonitoring: Bool = true) {
        guard startMonitoring else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "connectivity"))
    }
    func setOnlineForTesting(_ v: Bool) { isOnline = v }
}

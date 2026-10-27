import Foundation
import Network
import Observation

/// Observes reachability only to tell users the finder still works offline. The app never sends query text anywhere.
@Observable
final class ConnectivityMonitor {
    private(set) var isOffline = false

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            DispatchQueue.main.async {
                self?.isOffline = offline
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.demo.DogtorMyEyes.connectivity"))
    }

    deinit {
        monitor.cancel()
    }
}

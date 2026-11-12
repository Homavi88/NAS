import Foundation
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.synologysync.network")

    private(set) var isConnected = false
    private(set) var isExpensive = false
    private(set) var isConstrained = false
    private(set) var usesWiFi = false
    private(set) var usesWired = false
    private(set) var usesCellular = false

    /// Heuristic for "домашняя / локальная сеть": Wi‑Fi или Ethernet, без cellular.
    var isLikelyLocalNetwork: Bool {
        isConnected && (usesWiFi || usesWired) && !usesCellular
    }

    var statusTitle: String {
        if !isConnected { return "Нет сети" }
        if usesWiFi { return "Wi‑Fi" }
        if usesWired { return "Проводная сеть" }
        if usesCellular { return "Сотовая сеть" }
        return "Подключено"
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func apply(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        usesWiFi = path.usesInterfaceType(.wifi)
        usesWired = path.usesInterfaceType(.wiredEthernet)
        usesCellular = path.usesInterfaceType(.cellular)
    }
}

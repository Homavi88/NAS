import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class PowerMonitor {
    private(set) var batteryState: UIDevice.BatteryState = .unknown
    private(set) var batteryLevel: Float = 1

    var isChargingOrFull: Bool {
        switch batteryState {
        case .charging, .full: true
        default: false
        }
    }

    var statusTitle: String {
        switch batteryState {
        case .charging: "На зарядке"
        case .full: "Заряжен"
        case .unplugged: "От сети питания"
        default: "Неизвестно"
        }
    }

    private var observers: [NSObjectProtocol] = []

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()

        let stateObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        let levelObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        observers = [stateObserver, levelObserver]
    }

    private func refresh() {
        batteryState = UIDevice.current.batteryState
        batteryLevel = UIDevice.current.batteryLevel
    }
}

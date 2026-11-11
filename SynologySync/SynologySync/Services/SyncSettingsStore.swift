import Foundation
import Observation

@Observable
@MainActor
final class SyncSettingsStore {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let destinationPath = "sync.destinationPath"
        static let autoSyncEnabled = "sync.autoEnabled"
        static let requireLocalNetwork = "sync.requireLocalNetwork"
        static let requireCharging = "sync.requireCharging"
        static let lastSyncAt = "sync.lastSyncAt"
        static let syncedAssetIDs = "sync.syncedAssetIDs"
        static let appearance = "app.appearance"
    }

    var destinationPath: String {
        didSet { defaults.set(destinationPath, forKey: Keys.destinationPath) }
    }

    var autoSyncEnabled: Bool {
        didSet { defaults.set(autoSyncEnabled, forKey: Keys.autoSyncEnabled) }
    }

    var requireLocalNetwork: Bool {
        didSet { defaults.set(requireLocalNetwork, forKey: Keys.requireLocalNetwork) }
    }

    var requireCharging: Bool {
        didSet { defaults.set(requireCharging, forKey: Keys.requireCharging) }
    }

    var lastSyncAt: Date? {
        didSet { defaults.set(lastSyncAt, forKey: Keys.lastSyncAt) }
    }

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var syncedAssetIDs: Set<String> {
        didSet { defaults.set(Array(syncedAssetIDs), forKey: Keys.syncedAssetIDs) }
    }

    init() {
        destinationPath = defaults.string(forKey: Keys.destinationPath) ?? ""
        autoSyncEnabled = defaults.object(forKey: Keys.autoSyncEnabled) as? Bool ?? false
        requireLocalNetwork = defaults.object(forKey: Keys.requireLocalNetwork) as? Bool ?? true
        requireCharging = defaults.object(forKey: Keys.requireCharging) as? Bool ?? true
        lastSyncAt = defaults.object(forKey: Keys.lastSyncAt) as? Date
        if let raw = defaults.string(forKey: Keys.appearance),
           let value = AppAppearance(rawValue: raw) {
            appearance = value
        } else {
            appearance = .system
        }
        syncedAssetIDs = Set(defaults.stringArray(forKey: Keys.syncedAssetIDs) ?? [])
    }

    func markSynced(_ ids: [String]) {
        var current = syncedAssetIDs
        ids.forEach { current.insert($0) }
        syncedAssetIDs = current
        lastSyncAt = .now
    }
}

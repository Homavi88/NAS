import Foundation
import Observation

enum PhotoSyncState: Equatable {
    case idle
    case preparing
    case syncing(current: Int, total: Int, fileName: String)
    case completed(uploaded: Int, skipped: Int)
    case blocked(reason: String)
    case failed(String)
}

@Observable
@MainActor
final class PhotoSyncEngine {
    private(set) var state: PhotoSyncState = .idle
    private(set) var pendingCount = 0

    private var client: SynologyClient?
    private var settings: SyncSettingsStore?
    private var network: NetworkMonitor?
    private var power: PowerMonitor?
    private var session: NASSession?
    private let photos = PhotoLibraryService()
    private var syncTask: Task<Void, Never>?
    private var conditionObserversStarted = false

    func configure(
        client: SynologyClient,
        settings: SyncSettingsStore,
        network: NetworkMonitor,
        power: PowerMonitor
    ) {
        self.client = client
        self.settings = settings
        self.network = network
        self.power = power
        startConditionObserversIfNeeded()
    }

    func attach(session: NASSession) {
        self.session = session
    }

    func detach() {
        syncTask?.cancel()
        syncTask = nil
        session = nil
        state = .idle
    }

    func refreshPendingCount() async {
        guard let settings else { return }
        do {
            let assets = try await photos.fetchAllImageAssets()
            let synced = settings.syncedAssetIDs
            pendingCount = assets.filter { !synced.contains($0.id) }.count
        } catch {
            pendingCount = 0
        }
    }

    func evaluateAutoSync() {
        guard let settings, settings.autoSyncEnabled else { return }
        guard canStartAutomaticSync() else { return }
        startSync(manual: false)
    }

    func startSync(manual: Bool) {
        if case .syncing = state { return }
        guard let client, let settings, let session else {
            state = .failed("Нет активного подключения к NAS")
            return
        }

        let destination = settings.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else {
            state = .blocked(reason: "Выберите папку на NAS для сохранения фото")
            return
        }

        if !manual, let block = automaticBlockReason() {
            state = .blocked(reason: block)
            return
        }

        syncTask?.cancel()
        syncTask = Task { [weak self] in
            await self?.runSync(
                client: client,
                settings: settings,
                session: session,
                destination: destination
            )
        }
    }

    func cancel() {
        syncTask?.cancel()
        syncTask = nil
        state = .idle
    }

    private func runSync(
        client: SynologyClient,
        settings: SyncSettingsStore,
        session: NASSession,
        destination: String
    ) async {
        state = .preparing

        do {
            let assets = try await photos.fetchAllImageAssets()
            let synced = settings.syncedAssetIDs
            let pending = assets.filter { !synced.contains($0.id) }

            pendingCount = pending.count
            guard !pending.isEmpty else {
                state = .completed(uploaded: 0, skipped: assets.count)
                return
            }

            var uploaded = 0
            var skipped = 0
            var newlySynced: [String] = []

            for (index, asset) in pending.enumerated() {
                try Task.checkCancellation()

                // Re-check conditions for automatic long-running sync.
                if settings.autoSyncEnabled, let block = automaticBlockReason() {
                    settings.markSynced(newlySynced)
                    state = .blocked(reason: block)
                    await refreshPendingCount()
                    return
                }

                do {
                    let exported = try await photos.exportImageData(forLocalIdentifier: asset.id)
                    state = .syncing(current: index + 1, total: pending.count, fileName: exported.fileName)
                    try await client.upload(
                        session: session,
                        folderPath: destination,
                        fileName: exported.fileName,
                        data: exported.data,
                        overwrite: false
                    )
                    newlySynced.append(asset.id)
                    uploaded += 1
                } catch {
                    // Keep going; duplicates / transient failures are skipped.
                    skipped += 1
                }
            }

            settings.markSynced(newlySynced)
            state = .completed(uploaded: uploaded, skipped: skipped)
            await refreshPendingCount()
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func canStartAutomaticSync() -> Bool {
        automaticBlockReason() == nil
            && session != nil
            && !(settings?.destinationPath.isEmpty ?? true)
    }

    private func automaticBlockReason() -> String? {
        guard let settings, let network, let power else {
            return "Синхронизация ещё не настроена"
        }
        guard settings.autoSyncEnabled else { return "Автосинхронизация выключена" }

        if settings.requireLocalNetwork && !network.isLikelyLocalNetwork {
            return "Нужна локальная сеть (Wi‑Fi)"
        }
        if settings.requireCharging && !power.isChargingOrFull {
            return "Подключите iPhone к питанию"
        }
        return nil
    }

    private func startConditionObserversIfNeeded() {
        guard !conditionObserversStarted else { return }
        conditionObserversStarted = true

        // Poll conditions lightly; battery/path updates already refresh observable state.
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                self?.evaluateAutoSync()
            }
        }
    }
}

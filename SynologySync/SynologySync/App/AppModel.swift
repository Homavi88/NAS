import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppModel {
    var session: NASSession?
    var isBootstrapping = true
    var appearance: AppAppearance = .system

    let credentialsStore = CredentialsStore()
    let synologyClient = SynologyClient()
    let photoSyncEngine = PhotoSyncEngine()
    let networkMonitor = NetworkMonitor()
    let powerMonitor = PowerMonitor()
    let syncSettings = SyncSettingsStore()

    var isConnected: Bool { session != nil }

    func bootstrap() async {
        defer { isBootstrapping = false }

        appearance = syncSettings.appearance
        photoSyncEngine.configure(
            client: synologyClient,
            settings: syncSettings,
            network: networkMonitor,
            power: powerMonitor
        )

        guard let saved = credentialsStore.load() else { return }

        do {
            let session = try await synologyClient.login(using: saved)
            self.session = session
            photoSyncEngine.attach(session: session)
            photoSyncEngine.evaluateAutoSync()
        } catch {
            // Keep credentials; user can reconnect from Connection screen.
        }
    }

    func connect(with credentials: NASCredentials) async throws {
        let session = try await synologyClient.login(using: credentials)
        credentialsStore.save(credentials)
        self.session = session
        photoSyncEngine.attach(session: session)
        photoSyncEngine.evaluateAutoSync()
    }

    func disconnect() async {
        if let session {
            try? await synologyClient.logout(session: session)
        }
        photoSyncEngine.detach()
        self.session = nil
        credentialsStore.clear()
    }

    func updateAppearance(_ value: AppAppearance) {
        appearance = value
        syncSettings.appearance = value
    }
}

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Системная"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

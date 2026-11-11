import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab: AppTab = .files

    var body: some View {
        Group {
            if appModel.isBootstrapping {
                LaunchSplashView()
            } else if appModel.isConnected {
                TabView(selection: $selectedTab) {
                    Tab("Файлы", systemImage: "folder.fill", value: .files) {
                        FilesRootView()
                    }

                    Tab("Фото", systemImage: "photo.on.rectangle.angled", value: .photos) {
                        PhotoSyncView()
                    }

                    Tab("Настройки", systemImage: "gearshape.fill", value: .settings) {
                        SettingsView()
                    }
                }
                .tint(IOS27Theme.auroraTop)
            } else {
                ConnectionView()
            }
        }
        .task {
            await appModel.bootstrap()
        }
    }
}

private enum AppTab: Hashable {
    case files
    case photos
    case settings
}

struct LaunchSplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            IOS27Theme.meshBackground

            VStack(spacing: 18) {
                Image(systemName: "externaldrive.fill.badge.wifi")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(IOS27Theme.heroGradient)
                    .symbolEffect(.pulse, options: .repeating, value: pulse)
                    .onAppear { pulse = true }

                Text("Synology Sync")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(IOS27Theme.ink)

                Text("Подключение к NAS…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

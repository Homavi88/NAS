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

                    Tab("Фото", systemImage: "photo.stack.fill", value: .photos) {
                        PhotoSyncView()
                    }

                    Tab("Настройки", systemImage: "gearshape.fill", value: .settings) {
                        SettingsView()
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
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
    var body: some View {
        ZStack {
            IOS27Theme.meshBackground

            VStack(spacing: 20) {
                BrandMark(size: 88)

                Text("Silica")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(IOS27Theme.ink)

                Text("Подключение к NAS…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular.interactive(),
                        in: RoundedRectangle(cornerRadius: 36, style: .continuous)
                    )
            }
        }
    }
}

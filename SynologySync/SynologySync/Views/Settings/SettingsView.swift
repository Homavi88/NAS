import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showDisconnectConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Подключение") {
                    LabeledContent("Пользователь", value: appModel.session?.username ?? "—")
                    LabeledContent("Сервер", value: appModel.session?.baseURL.host() ?? "—")
                    LabeledContent("Сеть", value: appModel.networkMonitor.statusTitle)
                    LabeledContent("Питание", value: appModel.powerMonitor.statusTitle)
                }

                Section("Оформление") {
                    Picker("Тема", selection: Binding(
                        get: { appModel.appearance },
                        set: { appModel.updateAppearance($0) }
                    )) {
                        ForEach(AppAppearance.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                Section("Синхронизация фото") {
                    LabeledContent("Папка", value: appModel.syncSettings.destinationPath.isEmpty
                                    ? "Не выбрана"
                                    : appModel.syncSettings.destinationPath)
                    Toggle("Автосинхронизация", isOn: Binding(
                        get: { appModel.syncSettings.autoSyncEnabled },
                        set: {
                            appModel.syncSettings.autoSyncEnabled = $0
                            appModel.photoSyncEngine.evaluateAutoSync()
                        }
                    ))
                    Toggle("Только Wi‑Fi / локальная сеть", isOn: Binding(
                        get: { appModel.syncSettings.requireLocalNetwork },
                        set: { appModel.syncSettings.requireLocalNetwork = $0 }
                    ))
                    Toggle("Только при зарядке", isOn: Binding(
                        get: { appModel.syncSettings.requireCharging },
                        set: { appModel.syncSettings.requireCharging = $0 }
                    ))
                }

                Section {
                    Button("Сбросить журнал синхронизации", role: .destructive) {
                        appModel.syncSettings.syncedAssetIDs = []
                        Task { await appModel.photoSyncEngine.refreshPendingCount() }
                    }
                    Button("Отключиться от NAS", role: .destructive) {
                        showDisconnectConfirm = true
                    }
                } footer: {
                    Text("Сброс журнала заставит повторно проверить фото. Файлы на NAS и в Фото не удаляются.")
                }

                Section("О приложении") {
                    LabeledContent("Название", value: "Silica")
                    LabeledContent("Цель", value: "iPhone 17 Pro+")
                    LabeledContent("Дизайн", value: "iOS 27.2 Liquid Glass")
                    LabeledContent("NAS", value: "Synology File Station")
                }
            }
            .scrollContentBackground(.hidden)
            .ios27ScreenBackground()
            .navigationTitle("Настройки")
            .confirmationDialog(
                "Отключить NAS?",
                isPresented: $showDisconnectConfirm,
                titleVisibility: .visible
            ) {
                Button("Отключить", role: .destructive) {
                    Task { await appModel.disconnect() }
                }
                Button("Отмена", role: .cancel) {}
            }
        }
    }
}

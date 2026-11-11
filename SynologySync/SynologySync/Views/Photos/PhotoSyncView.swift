import SwiftUI

struct PhotoSyncView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showFolderPicker = false
    @State private var appear = false

    private var settings: SyncSettingsStore { appModel.syncSettings }
    private var engine: PhotoSyncEngine { appModel.photoSyncEngine }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    statusHero
                    destinationCard
                    conditionsCard
                    actionsCard
                    activityCard
                }
                .padding(20)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)
            }
            .ios27ScreenBackground()
            .navigationTitle("Синхронизация")
            .task {
                await engine.refreshPendingCount()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    appear = true
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView(selectedPath: Binding(
                    get: { settings.destinationPath },
                    set: { settings.destinationPath = $0 }
                ))
                .presentationDetents([.large])
            }
        }
    }

    private var statusHero: some View {
        GlassPanel(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    LiquidGlassIcon(systemName: "photo.stack.fill", size: 20)
                    Text("Резерв Фото → NAS")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(IOS27Theme.ink)
                }

                Text("Фото копируются на Synology без удаления с iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    StatusChip(
                        title: "\(engine.pendingCount) новых",
                        systemImage: "photo.stack.fill"
                    )
                    StatusChip(
                        title: appModel.networkMonitor.statusTitle,
                        systemImage: "wifi",
                        tint: appModel.networkMonitor.isLikelyLocalNetwork ? .green : .orange
                    )
                    StatusChip(
                        title: appModel.powerMonitor.statusTitle,
                        systemImage: "bolt.fill",
                        tint: appModel.powerMonitor.isChargingOrFull ? .green : .orange
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var destinationCard: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Label("Папка на NAS", systemImage: "folder.fill")
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)

                if settings.destinationPath.isEmpty {
                    Text("Не выбрана")
                        .foregroundStyle(.secondary)
                } else {
                    Text(settings.destinationPath)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(IOS27Theme.ink)
                        .textSelection(.enabled)
                }

                Button {
                    showFolderPicker = true
                } label: {
                    Label(
                        settings.destinationPath.isEmpty ? "Выбрать папку" : "Изменить папку",
                        systemImage: "folder.badge.gearshape"
                    )
                }
                .buttonStyle(SecondaryGlassButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var conditionsCard: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label("Автоматическая синхронизация", systemImage: "clock.arrow.2.circlepath")
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)

                Toggle(isOn: Binding(
                    get: { settings.autoSyncEnabled },
                    set: {
                        settings.autoSyncEnabled = $0
                        engine.evaluateAutoSync()
                    }
                )) {
                    Label("Включить автосинхронизацию", systemImage: "arrow.triangle.2.circlepath")
                }
                .tint(IOS27Theme.auroraTop)

                Toggle(isOn: Binding(
                    get: { settings.requireLocalNetwork },
                    set: {
                        settings.requireLocalNetwork = $0
                        engine.evaluateAutoSync()
                    }
                )) {
                    Label("Только в локальной сети (Wi‑Fi)", systemImage: "wifi")
                }
                .tint(IOS27Theme.auroraTop)
                .disabled(!settings.autoSyncEnabled)

                Toggle(isOn: Binding(
                    get: { settings.requireCharging },
                    set: {
                        settings.requireCharging = $0
                        engine.evaluateAutoSync()
                    }
                )) {
                    Label("Только при зарядке", systemImage: "battery.100.bolt")
                }
                .tint(IOS27Theme.auroraTop)
                .disabled(!settings.autoSyncEnabled)

                Text("Оригиналы на телефоне не удаляются. Уже отправленные снимки пропускаются.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            Button {
                engine.startSync(manual: true)
            } label: {
                Label("Синхронизировать сейчас", systemImage: "arrow.triangle.2.circlepath.circle.fill")
            }
            .buttonStyle(PrimaryGlassButtonStyle())

            if case .syncing = engine.state {
                Button(role: .cancel) {
                    engine.cancel()
                } label: {
                    Label("Остановить", systemImage: "stop.circle.fill")
                }
                .buttonStyle(SecondaryGlassButtonStyle())
            }
        }
    }

    private var activityCard: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label("Статус", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if case .syncing(let current, let total, _) = engine.state {
                    ProgressView(value: Double(current), total: Double(max(total, 1)))
                        .tint(IOS27Theme.auroraTop)
                }

                if let last = settings.lastSyncAt {
                    Text("Последняя синхронизация: \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusText: String {
        switch engine.state {
        case .idle:
            return "Ожидание"
        case .preparing:
            return "Подготовка библиотеки Фото…"
        case .syncing(let current, let total, let fileName):
            return "Загрузка \(current)/\(total): \(fileName)"
        case .completed(let uploaded, let skipped):
            return "Готово. Загружено: \(uploaded), пропущено: \(skipped)"
        case .blocked(let reason):
            return reason
        case .failed(let message):
            return message
        }
    }
}

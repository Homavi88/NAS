import SwiftUI

struct FilesRootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var shares: [NASShare] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLoading && shares.isEmpty {
                    ProgressView("Загрузка общих папок…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, shares.isEmpty {
                    ContentUnavailableView(
                        "Не удалось загрузить",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(shares) { share in
                                NavigationLink(value: FileBrowserDestination.folder(path: share.path, title: share.name)) {
                                    HStack(spacing: 14) {
                                        LiquidGlassIcon(systemName: share.systemImage, size: 18)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(share.name)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(IOS27Theme.ink)
                                            Text(share.path)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(14)
                                    .background { liquidGlassBackground(cornerRadius: 22) }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)

                        Text("Создавайте, переименовывайте, удаляйте и загружайте файлы прямо на NAS.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .ios27ScreenBackground()
            .navigationTitle("Файлы")
            .navigationDestination(for: FileBrowserDestination.self) { destination in
                switch destination {
                case .shareRoot:
                    EmptyView()
                case .folder(let path, let title):
                    FileBrowserView(folderPath: path, title: title)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadShares() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .task { await loadShares() }
            .refreshable { await loadShares() }
        }
    }

    private func loadShares() async {
        guard let session = appModel.session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            shares = try await appModel.synologyClient.listShares(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

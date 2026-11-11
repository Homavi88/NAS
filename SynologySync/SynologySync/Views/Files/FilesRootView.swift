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
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    List {
                        Section {
                            ForEach(shares) { share in
                                NavigationLink(value: FileBrowserDestination.folder(path: share.path, title: share.name)) {
                                    Label(share.name, systemImage: "externaldrive.fill")
                                        .font(.body.weight(.medium))
                                }
                            }
                        } header: {
                            Text("Общие папки")
                        } footer: {
                            Text("Создавайте, переименовывайте, удаляйте и загружайте файлы прямо на NAS.")
                        }
                    }
                    .scrollContentBackground(.hidden)
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
                    }
                }
            }
            .task {
                await loadShares()
            }
            .refreshable {
                await loadShares()
            }
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

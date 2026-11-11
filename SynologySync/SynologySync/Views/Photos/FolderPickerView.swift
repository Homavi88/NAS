import SwiftUI

struct FolderPickerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedPath: String

    @State private var pathStack: [FolderNode] = []
    @State private var currentItems: [NASFileItem] = []
    @State private var shares: [NASShare] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var currentPath: String? {
        pathStack.last?.path
    }

    private var title: String {
        pathStack.last?.name ?? "Выбор папки"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && currentItems.isEmpty && shares.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    List {
                        if pathStack.isEmpty {
                            Section("Общие папки") {
                                ForEach(shares) { share in
                                    Button {
                                        Task { await open(path: share.path, name: share.name) }
                                    } label: {
                                        Label(share.name, systemImage: "externaldrive.fill")
                                    }
                                }
                            }
                        } else {
                            Section {
                                ForEach(currentItems.filter(\.isDirectory)) { folder in
                                    Button {
                                        Task { await open(path: folder.path, name: folder.name) }
                                    } label: {
                                        Label(folder.name, systemImage: "folder.fill")
                                    }
                                }
                            } header: {
                                Text(currentPath ?? "")
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .ios27ScreenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if pathStack.isEmpty {
                        Button("Закрыть") { dismiss() }
                    } else {
                        Button("Назад") {
                            pathStack.removeLast()
                            Task { await reload() }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Выбрать") {
                        if let currentPath {
                            selectedPath = currentPath
                            dismiss()
                        }
                    }
                    .disabled(currentPath == nil)
                    .fontWeight(.semibold)
                }
            }
            .task { await reload() }
        }
    }

    private func open(path: String, name: String) async {
        pathStack.append(FolderNode(path: path, name: name))
        await reload()
    }

    private func reload() async {
        guard let session = appModel.session else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if let currentPath {
                currentItems = try await appModel.synologyClient.listFiles(session: session, folderPath: currentPath)
                shares = []
            } else {
                shares = try await appModel.synologyClient.listShares(session: session)
                currentItems = []
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FolderNode: Hashable {
    let path: String
    let name: String
}

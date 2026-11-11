import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @Environment(AppModel.self) private var appModel

    let folderPath: String
    let title: String

    @State private var items: [NASFileItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var renameTarget: NASFileItem?
    @State private var renameText = ""
    @State private var deleteTarget: NASFileItem?
    @State private var isImporterPresented = false
    @State private var busyMessage: String?
    @State private var selectionMode = false
    @State private var selectedPaths: Set<String> = []

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView("Загрузка…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, items.isEmpty {
                ContentUnavailableView(
                    "Ошибка",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if items.isEmpty {
                ContentUnavailableView(
                    "Пустая папка",
                    systemImage: "folder",
                    description: Text("Загрузите файлы или создайте новую папку.")
                )
            } else {
                List(selection: $selectedPaths) {
                    ForEach(items) { item in
                        Group {
                            if item.isDirectory && !selectionMode {
                                NavigationLink(value: FileBrowserDestination.folder(path: item.path, title: item.name)) {
                                    FileRow(item: item)
                                }
                            } else {
                                FileRow(item: item)
                            }
                        }
                        .tag(item.path)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteTarget = item
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                            Button {
                                renameTarget = item
                                renameText = item.name
                            } label: {
                                Label("Имя", systemImage: "pencil")
                            }
                            .tint(IOS27Theme.auroraTop)
                        }
                        .contextMenu {
                            Button {
                                renameTarget = item
                                renameText = item.name
                            } label: {
                                Label("Переименовать", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleteTarget = item
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                .environment(\.editMode, .constant(selectionMode ? .active : .inactive))
                .scrollContentBackground(.hidden)
            }
        }
        .ios27ScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    selectionMode.toggle()
                    if !selectionMode { selectedPaths.removeAll() }
                } label: {
                    Image(systemName: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                }

                Menu {
                    Button {
                        showCreateFolder = true
                    } label: {
                        Label("Новая папка", systemImage: "folder.badge.plus")
                    }
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Загрузить файл", systemImage: "square.and.arrow.up")
                    }
                    if selectionMode, !selectedPaths.isEmpty {
                        Button(role: .destructive) {
                            Task { await deleteSelected() }
                        } label: {
                            Label("Удалить выбранные", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if let busyMessage {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    GlassPanel {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(busyMessage)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .alert("Новая папка", isPresented: $showCreateFolder) {
            TextField("Имя папки", text: $newFolderName)
            Button("Отмена", role: .cancel) { newFolderName = "" }
            Button("Создать") {
                Task { await createFolder() }
            }
        }
        .alert("Переименовать", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Новое имя", text: $renameText)
            Button("Отмена", role: .cancel) { renameTarget = nil }
            Button("Сохранить") {
                Task { await renameItem() }
            }
        }
        .confirmationDialog(
            "Удалить «\(deleteTarget?.name ?? "")»?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                Task { await deleteItem() }
            }
            Button("Отмена", role: .cancel) { deleteTarget = nil }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            Task { await handleImport(result) }
        }
    }

    private func reload() async {
        guard let session = appModel.session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await appModel.synologyClient.listFiles(session: session, folderPath: folderPath)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createFolder() async {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""
        guard !name.isEmpty, let session = appModel.session else { return }
        busyMessage = "Создание папки…"
        defer { busyMessage = nil }
        do {
            try await appModel.synologyClient.createFolder(session: session, parentPath: folderPath, name: name)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameItem() async {
        guard let target = renameTarget, let session = appModel.session else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        renameTarget = nil
        guard !name.isEmpty else { return }
        busyMessage = "Переименование…"
        defer { busyMessage = nil }
        do {
            try await appModel.synologyClient.rename(session: session, path: target.path, newName: name)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItem() async {
        guard let target = deleteTarget, let session = appModel.session else { return }
        deleteTarget = nil
        busyMessage = "Удаление…"
        defer { busyMessage = nil }
        do {
            try await appModel.synologyClient.delete(session: session, paths: [target.path])
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelected() async {
        guard let session = appModel.session, !selectedPaths.isEmpty else { return }
        busyMessage = "Удаление…"
        defer { busyMessage = nil }
        do {
            try await appModel.synologyClient.delete(session: session, paths: Array(selectedPaths))
            selectedPaths.removeAll()
            selectionMode = false
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        guard let session = appModel.session else { return }
        do {
            let urls = try result.get()
            busyMessage = "Загрузка…"
            defer { busyMessage = nil }

            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                try await appModel.synologyClient.upload(
                    session: session,
                    folderPath: folderPath,
                    fileName: url.lastPathComponent,
                    data: data,
                    overwrite: false
                )
            }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FileRow: View {
    let item: NASFileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .foregroundStyle(item.isDirectory ? IOS27Theme.auroraTop : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.displaySize)
                    if let modified = item.modified {
                        Text(modified, style: .date)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

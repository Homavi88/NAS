import Foundation
import UniformTypeIdentifiers

struct NASFileItem: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date?
    let additional: AdditionalInfo?

    var id: String { path }

    var displaySize: String {
        guard !isDirectory else { return "Папка" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var systemImage: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp":
            return "photo"
        case "mp4", "mov", "m4v":
            return "film"
        case "pdf":
            return "doc.richtext"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        case "mp3", "aac", "flac", "wav":
            return "music.note"
        default:
            return "doc.fill"
        }
    }

    struct AdditionalInfo: Hashable, Sendable {
        var realPath: String?
        var owner: String?
    }
}

struct NASShare: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    var id: String { path }
}

enum FileBrowserDestination: Hashable {
    case shareRoot
    case folder(path: String, title: String)
}

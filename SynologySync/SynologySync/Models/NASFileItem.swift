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

    /// Modern SF Symbol set tuned for iOS 27 hierarchical rendering.
    var systemImage: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "raw", "dng":
            return "photo.fill"
        case "mp4", "mov", "m4v", "mkv":
            return "film.fill"
        case "pdf":
            return "doc.richtext.fill"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox.fill"
        case "mp3", "aac", "flac", "wav", "m4a":
            return "music.note"
        case "pages", "doc", "docx", "txt", "rtf", "md":
            return "doc.text.fill"
        case "xls", "xlsx", "numbers", "csv":
            return "tablecells.fill"
        case "ppt", "pptx", "key":
            return "rectangle.stack.fill.badge.person.crop"
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

    var systemImage: String {
        let lower = name.lowercased()
        if lower.contains("photo") || lower.contains("image") || lower.contains("media") {
            return "photo.on.rectangle.angled"
        }
        if lower.contains("video") || lower.contains("movie") {
            return "film.fill"
        }
        if lower.contains("home") {
            return "house.fill"
        }
        if lower.contains("backup") || lower.contains("bak") {
            return "externaldrive.fill.badge.checkmark"
        }
        if lower.contains("doc") {
            return "doc.text.fill"
        }
        return "externaldrive.fill.badge.wifi"
    }
}

enum FileBrowserDestination: Hashable {
    case shareRoot
    case folder(path: String, title: String)
}

import Foundation

struct SynologyAPIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: SynologyAPIError?
}

struct SynologyAPIError: Decodable, Error, LocalizedError {
    let code: Int

    var errorDescription: String? {
        switch code {
        case 100: "Unknown error"
        case 101: "Invalid parameter"
        case 102: "API does not exist"
        case 103: "Method does not exist"
        case 104: "This API version is not supported"
        case 105: "Permission denied"
        case 106: "Session timeout"
        case 107: "Session interrupted"
        case 119: "SID not found"
        case 400: "No such account or incorrect password"
        case 401: "Account disabled"
        case 402: "Permission denied"
        case 403: "2-factor authentication code required"
        case 404: "Failed to authenticate 2-factor verification code"
        case 406: "Enforce to authenticate with 2-factor"
        case 407: "Max tries of 2-factor authentication"
        default: "Synology error \(code)"
        }
    }
}

struct AuthData: Decodable {
    let sid: String
    let synotoken: String?
}

struct ShareListData: Decodable {
    let shares: [ShareDTO]
    let total: Int?
    let offset: Int?
}

struct ShareDTO: Decodable {
    let path: String
    let name: String
    let additional: ShareAdditional?

    struct ShareAdditional: Decodable {
        let real_path: String?
    }
}

struct FileListData: Decodable {
    let files: [FileDTO]
    let total: Int?
    let offset: Int?
}

struct FileDTO: Decodable {
    let path: String
    let name: String
    let isdir: Bool
    let additional: FileAdditional?

    struct FileAdditional: Decodable {
        let size: Int64?
        let time: TimeInfo?
        let real_path: String?
        let owner: OwnerInfo?

        struct TimeInfo: Decodable {
            let mtime: TimeInterval?
        }

        struct OwnerInfo: Decodable {
            let user: String?
        }
    }

    func toModel() -> NASFileItem {
        let modified: Date? = {
            guard let mtime = additional?.time?.mtime else { return nil }
            return Date(timeIntervalSince1970: mtime)
        }()

        return NASFileItem(
            path: path,
            name: name,
            isDirectory: isdir,
            size: additional?.size ?? 0,
            modified: modified,
            additional: .init(
                realPath: additional?.real_path,
                owner: additional?.owner?.user
            )
        )
    }
}

struct EmptyData: Decodable {}

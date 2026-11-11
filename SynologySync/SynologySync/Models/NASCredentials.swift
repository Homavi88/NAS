import Foundation

struct NASCredentials: Codable, Equatable, Sendable {
    var host: String
    var port: Int
    var useHTTPS: Bool
    var username: String
    var password: String
    var quickConnectID: String
    var connectionMode: ConnectionMode

    enum ConnectionMode: String, Codable, CaseIterable, Identifiable, Sendable {
        case local
        case quickConnect
        case customURL

        var id: String { rawValue }

        var title: String {
            switch self {
            case .local: "Локальная сеть"
            case .quickConnect: "QuickConnect / Интернет"
            case .customURL: "Свой адрес"
            }
        }
    }

    static let empty = NASCredentials(
        host: "",
        port: 5001,
        useHTTPS: true,
        username: "",
        password: "",
        quickConnectID: "",
        connectionMode: .local
    )

    var baseURLString: String {
        switch connectionMode {
        case .local, .customURL:
            let scheme = useHTTPS ? "https" : "http"
            let normalizedHost = host
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return "\(scheme)://\(normalizedHost):\(port)"
        case .quickConnect:
            let id = quickConnectID.trimmingCharacters(in: .whitespacesAndNewlines)
            return "https://\(id).quickconnect.to"
        }
    }
}

struct NASSession: Equatable, Sendable {
    var sid: String
    var baseURL: URL
    var username: String
    var synoToken: String?
}

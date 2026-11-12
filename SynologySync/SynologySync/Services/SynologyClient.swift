import Foundation
import UniformTypeIdentifiers

actor SynologyClient {
    private let urlSession: URLSession
    private var apiInfoCache: [String: APIInfo] = [:]

    struct APIInfo: Decodable, Sendable {
        let path: String
        let minVersion: Int
        let maxVersion: Int
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        // Many Synology installs use self-signed certs on LAN.
        urlSession = URLSession(
            configuration: config,
            delegate: InsecureSSLDelegate(),
            delegateQueue: nil
        )
    }

    func login(using credentials: NASCredentials) async throws -> NASSession {
        guard let baseURL = URL(string: credentials.baseURLString) else {
            throw SynologyClientError.invalidURL
        }

        try await refreshAPIInfo(baseURL: baseURL)

        let query: [String: String] = [
            "api": "SYNO.API.Auth",
            "version": "3",
            "method": "login",
            "account": credentials.username,
            "passwd": credentials.password,
            "session": "FileStation",
            "format": "sid"
        ]

        let response: SynologyAPIResponse<AuthData> = try await get(
            baseURL: baseURL,
            api: "SYNO.API.Auth",
            fallbackPath: "auth.cgi",
            query: query
        )

        guard response.success, let data = response.data else {
            throw response.error ?? SynologyClientError.loginFailed
        }

        return NASSession(
            sid: data.sid,
            baseURL: baseURL,
            username: credentials.username,
            synoToken: data.synotoken
        )
    }

    func logout(session nasSession: NASSession) async throws {
        let _: SynologyAPIResponse<EmptyData> = try await get(
            baseURL: nasSession.baseURL,
            api: "SYNO.API.Auth",
            fallbackPath: "auth.cgi",
            query: [
                "api": "SYNO.API.Auth",
                "version": "1",
                "method": "logout",
                "session": "FileStation",
                "_sid": nasSession.sid
            ]
        )
    }

    func listShares(session: NASSession) async throws -> [NASShare] {
        let response: SynologyAPIResponse<ShareListData> = try await get(
            baseURL: session.baseURL,
            api: "SYNO.FileStation.List",
            fallbackPath: "entry.cgi",
            query: [
                "api": "SYNO.FileStation.List",
                "version": "2",
                "method": "list_share",
                "additional": "real_path,owner,time,perm",
                "_sid": session.sid
            ]
        )

        guard response.success, let data = response.data else {
            throw response.error ?? SynologyClientError.requestFailed
        }

        return data.shares.map { NASShare(path: $0.path, name: $0.name) }
    }

    func listFiles(session: NASSession, folderPath: String) async throws -> [NASFileItem] {
        let response: SynologyAPIResponse<FileListData> = try await get(
            baseURL: session.baseURL,
            api: "SYNO.FileStation.List",
            fallbackPath: "entry.cgi",
            query: [
                "api": "SYNO.FileStation.List",
                "version": "2",
                "method": "list",
                "folder_path": folderPath,
                "additional": "size,time,owner,real_path",
                "sort_by": "name",
                "sort_direction": "asc",
                "_sid": session.sid
            ]
        )

        guard response.success, let data = response.data else {
            throw response.error ?? SynologyClientError.requestFailed
        }

        return data.files.map { $0.toModel() }
    }

    func createFolder(session: NASSession, parentPath: String, name: String) async throws {
        let response: SynologyAPIResponse<EmptyData> = try await get(
            baseURL: session.baseURL,
            api: "SYNO.FileStation.CreateFolder",
            fallbackPath: "entry.cgi",
            query: [
                "api": "SYNO.FileStation.CreateFolder",
                "version": "2",
                "method": "create",
                "folder_path": parentPath,
                "name": name,
                "force_parent": "false",
                "_sid": session.sid
            ]
        )

        guard response.success else {
            throw response.error ?? SynologyClientError.requestFailed
        }
    }

    func rename(session: NASSession, path: String, newName: String) async throws {
        let response: SynologyAPIResponse<EmptyData> = try await get(
            baseURL: session.baseURL,
            api: "SYNO.FileStation.Rename",
            fallbackPath: "entry.cgi",
            query: [
                "api": "SYNO.FileStation.Rename",
                "version": "2",
                "method": "rename",
                "path": path,
                "name": newName,
                "_sid": session.sid
            ]
        )

        guard response.success else {
            throw response.error ?? SynologyClientError.requestFailed
        }
    }

    func delete(session: NASSession, paths: [String]) async throws {
        let joined = paths
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }
            .joined(separator: ",")

        let response: SynologyAPIResponse<EmptyData> = try await get(
            baseURL: session.baseURL,
            api: "SYNO.FileStation.Delete",
            fallbackPath: "entry.cgi",
            query: [
                "api": "SYNO.FileStation.Delete",
                "version": "2",
                "method": "delete",
                "path": "[\(joined)]",
                "recursive": "true",
                "_sid": session.sid
            ]
        )

        guard response.success else {
            throw response.error ?? SynologyClientError.requestFailed
        }
    }

    func upload(
        session: NASSession,
        folderPath: String,
        fileName: String,
        data: Data,
        overwrite: Bool = false
    ) async throws {
        let cgi = try cgiURL(
            baseURL: session.baseURL,
            api: "SYNO.FileStation.Upload",
            fallbackPath: "entry.cgi"
        )

        var components = URLComponents(url: cgi, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.FileStation.Upload"),
            URLQueryItem(name: "version", value: "2"),
            URLQueryItem(name: "method", value: "upload"),
            URLQueryItem(name: "_sid", value: session.sid)
        ]

        guard let url = components.url else { throw SynologyClientError.invalidURL }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("path", folderPath)
        appendField("create_parents", "true")
        appendField("overwrite", overwrite ? "true" : "false")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        let mime = UTType(filenameExtension: (fileName as NSString).pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SynologyClientError.requestFailed
        }

        let decoded = try JSONDecoder().decode(SynologyAPIResponse<EmptyData>.self, from: responseData)
        guard decoded.success else {
            throw decoded.error ?? SynologyClientError.requestFailed
        }
    }

    func download(session: NASSession, path: String) async throws -> Data {
        let cgi = try cgiURL(
            baseURL: session.baseURL,
            api: "SYNO.FileStation.Download",
            fallbackPath: "entry.cgi"
        )

        var components = URLComponents(url: cgi, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.FileStation.Download"),
            URLQueryItem(name: "version", value: "2"),
            URLQueryItem(name: "method", value: "download"),
            URLQueryItem(name: "path", value: path),
            URLQueryItem(name: "mode", value: "download"),
            URLQueryItem(name: "_sid", value: session.sid)
        ]

        guard let url = components.url else { throw SynologyClientError.invalidURL }
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SynologyClientError.requestFailed
        }
        return data
    }

    // MARK: - Internals

    private struct APIInfoEnvelope: Decodable {
        let success: Bool
        let data: [String: APIInfo]?
    }

    private func refreshAPIInfo(baseURL: URL) async throws {
        let url = baseURL.appending(path: "webapi/query.cgi")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.API.Info"),
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "method", value: "query"),
            URLQueryItem(name: "query", value: "all")
        ]

        guard let requestURL = components.url else { throw SynologyClientError.invalidURL }
        let (data, _) = try await urlSession.data(from: requestURL)
        let envelope = try JSONDecoder().decode(APIInfoEnvelope.self, from: data)
        apiInfoCache = envelope.data ?? [:]
    }

    private func cgiURL(baseURL: URL, api: String, fallbackPath: String) throws -> URL {
        let relative = apiInfoCache[api]?.path ?? fallbackPath
        return baseURL.appending(path: "webapi").appending(path: relative)
    }

    private func get<T: Decodable>(
        baseURL: URL,
        api: String,
        fallbackPath: String,
        query: [String: String]
    ) async throws -> SynologyAPIResponse<T> {
        let cgi = try cgiURL(baseURL: baseURL, api: api, fallbackPath: fallbackPath)
        var components = URLComponents(url: cgi, resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw SynologyClientError.invalidURL }

        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SynologyClientError.requestFailed
        }
        return try JSONDecoder().decode(SynologyAPIResponse<T>.self, from: data)
    }
}

enum SynologyClientError: LocalizedError {
    case invalidURL
    case loginFailed
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Некорректный адрес NAS"
        case .loginFailed: "Не удалось войти на NAS"
        case .requestFailed: "Запрос к Synology не выполнен"
        }
    }
}

/// Allows trusted local Synology certificates (common on LAN).
final class InsecureSSLDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

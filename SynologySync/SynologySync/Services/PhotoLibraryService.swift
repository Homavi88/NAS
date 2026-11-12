import Foundation
import Photos
import UIKit

struct PhotoAssetItem: Identifiable, Hashable, Sendable {
    let id: String
    let creationDate: Date?
    let mediaType: PHAssetMediaType
    let pixelWidth: Int
    let pixelHeight: Int
}

enum PhotoLibraryServiceError: LocalizedError {
    case denied
    case limited
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied: "Нет доступа к Фото. Разрешите доступ в Настройках."
        case .limited: "Доступ к Фото ограничен."
        case .unavailable: "Библиотека Фото недоступна."
        }
    }
}

final class PhotoLibraryService: @unchecked Sendable {
    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func fetchAllImageAssets() async throws -> [PhotoAssetItem] {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryServiceError.denied
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeHiddenAssets = false
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var items: [PhotoAssetItem] = []
        items.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            items.append(
                PhotoAssetItem(
                    id: asset.localIdentifier,
                    creationDate: asset.creationDate,
                    mediaType: asset.mediaType,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight
                )
            )
        }
        return items
    }

    func exportImageData(forLocalIdentifier id: String) async throws -> (fileName: String, data: Data) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else {
            throw PhotoLibraryServiceError.unavailable
        }

        let resources = PHAssetResource.assetResources(for: asset)
        let resource = resources.first(where: { $0.type == .fullSizePhoto })
            ?? resources.first(where: { $0.type == .photo })
            ?? resources.first

        guard let resource else { throw PhotoLibraryServiceError.unavailable }

        let data = try await readResourceData(resource)
        let fileName = preferredFileName(for: asset, resource: resource)
        return (fileName, data)
    }

    private func preferredFileName(for asset: PHAsset, resource: PHAssetResource) -> String {
        if let name = resource.filename, !name.isEmpty {
            return name
        }
        let stamp = (asset.creationDate ?? .now).timeIntervalSince1970
        return "IMG_\(Int(stamp)).jpg"
    }

    private func readResourceData(_ resource: PHAssetResource) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            var collected = Data()
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { chunk in
                    collected.append(chunk)
                },
                completionHandler: { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: collected)
                    }
                }
            )
        }
    }
}

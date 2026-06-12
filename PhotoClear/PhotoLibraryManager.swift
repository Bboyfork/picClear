//
//  PhotoLibraryManager.swift
//  PhotoClear
//

import Combine
import Photos
import SwiftUI

struct AlbumInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let collection: PHAssetCollection
}

@MainActor
final class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var albums: [AlbumInfo] = []

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    func requestPermission() async {
        authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if isAuthorized { loadAlbums() }
    }

    // MARK: - 相册

    func loadAlbums() {
        var list: [AlbumInfo] = []
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        userAlbums.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: nil).count
            list.append(AlbumInfo(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? "未命名",
                count: count,
                collection: collection
            ))
        }
        albums = list
    }

    func createAlbum(named title: String) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
        }
        loadAlbums()
    }

    /// 删除相册及其中全部照片
    func deleteAlbum(_ info: AlbumInfo) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(in: info.collection, options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
            PHAssetCollectionChangeRequest.deleteAssetCollections([info.collection] as NSArray)
        }
        loadAlbums()
    }

    func album(withID id: String) -> AlbumInfo? {
        albums.first { $0.id == id }
    }

    // MARK: - 照片

    /// 取源相册的所有照片；sourceID 为空则取整个图库
    func fetchAssets(sourceAlbumID: String) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result: PHFetchResult<PHAsset>
        if let info = album(withID: sourceAlbumID) {
            result = PHAsset.fetchAssets(in: info.collection, options: options)
        } else {
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            result = PHAsset.fetchAssets(with: options)
        }

        var list: [PHAsset] = []
        list.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in list.append(asset) }
        return list
    }

    /// 把照片加入指定相册（iOS 的"移动"实质是加入相册引用）
    func add(_ asset: PHAsset, toAlbumID albumID: String) async throws {
        guard let info = album(withID: albumID) else {
            throw PhotoClearError.albumNotSet
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest(for: info.collection)
            request?.addAssets([asset] as NSArray)
        }
    }

    /// 把照片移出指定相册；albumID 为空（整个图库）时无操作
    func remove(_ asset: PHAsset, fromAlbumID albumID: String) async throws {
        guard let info = album(withID: albumID) else { return }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest(for: info.collection)
            request?.removeAssets([asset] as NSArray)
        }
    }
}

enum PhotoClearError: LocalizedError {
    case albumNotSet

    var errorDescription: String? {
        switch self {
        case .albumNotSet: "目标相册未设置，请先到「设置」页选择相册"
        }
    }
}

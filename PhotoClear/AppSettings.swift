//
//  AppSettings.swift
//  PhotoClear
//

import Combine
import Foundation
import SwiftUI

/// 三个相册设置，存的是 PHAssetCollection 的 localIdentifier
@MainActor
final class AppSettings: ObservableObject {
    @Published var sourceAlbumID: String {
        didSet { UserDefaults.standard.set(sourceAlbumID, forKey: "sourceAlbumID") }
    }
    @Published var deleteAlbumID: String {
        didSet { UserDefaults.standard.set(deleteAlbumID, forKey: "deleteAlbumID") }
    }
    @Published var likeAlbumID: String {
        didSet { UserDefaults.standard.set(likeAlbumID, forKey: "likeAlbumID") }
    }
    /// 右滑保留的去向相册；空 = 原地不动
    @Published var keepAlbumID: String {
        didSet { UserDefaults.standard.set(keepAlbumID, forKey: "keepAlbumID") }
    }

    init() {
        let defaults = UserDefaults.standard
        sourceAlbumID = defaults.string(forKey: "sourceAlbumID") ?? ""
        deleteAlbumID = defaults.string(forKey: "deleteAlbumID") ?? ""
        likeAlbumID = defaults.string(forKey: "likeAlbumID") ?? ""
        keepAlbumID = defaults.string(forKey: "keepAlbumID") ?? ""
    }
}

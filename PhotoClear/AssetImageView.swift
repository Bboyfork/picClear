//
//  AssetImageView.swift
//  PhotoClear
//

import Photos
import SwiftUI

#if canImport(UIKit)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

/// 通用照片加载视图：传入 PHAsset 和目标尺寸
struct AssetImageView: View {
    let asset: PHAsset
    var targetSize = CGSize(width: 800, height: 800)

    @State private var image: PlatformImage?

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay { ProgressView() }
            }
        }
        .task(id: asset.localIdentifier) {
            image = await load()
        }
    }

    private func load() async -> PlatformImage? {
        let options = PHImageRequestOptions()
        // highQualityFormat 保证回调只触发一次
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }
}

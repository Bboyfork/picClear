//
//  AlbumDetailView.swift
//  PhotoClear
//

import Photos
import SwiftUI

/// 相册内照片网格，3 列方形缩略图，仿系统相册
struct AlbumDetailView: View {
    let album: AlbumInfo

    @EnvironmentObject var library: PhotoLibraryManager
    @State private var assets: [PHAsset] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollView {
            if assets.isEmpty {
                ContentUnavailableView(
                    "空相册",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("这个相册里还没有照片")
                )
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        squareCell(for: asset)
                    }
                }

                Text("\(assets.count) 张照片")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 16)
            }
        }
        .navigationTitle(album.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            assets = library.fetchAssets(sourceAlbumID: album.id)
        }
    }

    private func squareCell(for asset: PHAsset) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AssetImageView(asset: asset, targetSize: CGSize(width: 400, height: 400))
            }
            .clipped()
            .contentShape(Rectangle())
    }
}

//
//  SwipeView.swift
//  PhotoClear
//
//  首页：探探式卡片滑动
//  左滑 = 删除（移入删除相册）  右滑 = 保留  上滑 = 喜欢（移入喜欢相册）
//

import Photos
import SwiftUI

enum SwipeAction {
    case delete, keep, like
}

struct SwipeView: View {
    @EnvironmentObject var library: PhotoLibraryManager
    @EnvironmentObject var settings: AppSettings

    @State private var assets: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isFlyingOut = false
    @State private var errorMessage: String?
    @State private var processedCount = (deleted: 0, kept: 0, liked: 0)

    private let swipeThreshold: CGFloat = 110

    var body: some View {
        NavigationStack {
            Group {
                if !library.isAuthorized {
                    PermissionView()
                } else if assets.isEmpty {
                    emptyView
                } else if currentIndex >= assets.count {
                    finishedView
                } else {
                    cardStack
                }
            }
            .navigationTitle("整理照片")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("操作失败", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            if library.isAuthorized && assets.isEmpty { reload() }
        }
        .onChange(of: library.authorizationStatus) {
            if library.isAuthorized { reload() }
        }
    }

    // MARK: - 卡片堆

    private var cardStack: some View {
        VStack(spacing: 20) {
            statsBar

            GeometryReader { geo in
                ZStack {
                    // 下一张垫底，制造堆叠感
                    if currentIndex + 1 < assets.count {
                        card(for: assets[currentIndex + 1], size: geo.size)
                            .scaleEffect(0.92)
                            .offset(y: 14)
                            .allowsHitTesting(false)
                    }

                    card(for: assets[currentIndex], size: geo.size)
                        .overlay(swipeLabel)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width) / 18))
                        .gesture(dragGesture)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: dragOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            actionButtons
        }
        .padding()
    }

    private func card(for asset: PHAsset, size: CGSize) -> some View {
        AssetImageView(asset: asset, targetSize: CGSize(width: 1200, height: 1200))
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 8, y: 4)
    }

    // MARK: - 滑动标签

    @ViewBuilder
    private var swipeLabel: some View {
        let dx = dragOffset.width
        let dy = dragOffset.height

        if dx < -40 {
            badge("删除", color: .red, angle: 12)
                .opacity(min(Double(-dx) / 110, 1))
        } else if dx > 40 {
            badge("保留", color: .green, angle: -12)
                .opacity(min(Double(dx) / 110, 1))
        } else if dy < -40 {
            badge("喜欢 ♥", color: .pink, angle: 0)
                .opacity(min(Double(-dy) / 110, 1))
        }
    }

    private func badge(_ text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.system(size: 42, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(angle))
    }

    // MARK: - 手势

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isFlyingOut else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isFlyingOut else { return }
                let t = value.translation
                if t.width < -swipeThreshold {
                    perform(.delete)
                } else if t.width > swipeThreshold {
                    perform(.keep)
                } else if t.height < -swipeThreshold {
                    perform(.like)
                } else {
                    dragOffset = .zero
                }
            }
    }

    // MARK: - 执行动作

    private func perform(_ action: SwipeAction) {
        let asset = assets[currentIndex]
        isFlyingOut = true

        // 卡片飞出方向
        switch action {
        case .delete: dragOffset = CGSize(width: -700, height: 0)
        case .keep: dragOffset = CGSize(width: 700, height: 0)
        case .like: dragOffset = CGSize(width: 0, height: -900)
        }

        Task {
            do {
                switch action {
                case .delete:
                    try await library.add(asset, toAlbumID: settings.deleteAlbumID)
                    processedCount.deleted += 1
                case .like:
                    try await library.add(asset, toAlbumID: settings.likeAlbumID)
                    processedCount.liked += 1
                case .keep:
                    processedCount.kept += 1
                }
                try? await Task.sleep(for: .milliseconds(250))
                currentIndex += 1
            } catch {
                errorMessage = error.localizedDescription
            }
            dragOffset = .zero
            isFlyingOut = false
        }
    }

    // MARK: - 底部按钮（点按也能触发）

    private var actionButtons: some View {
        HStack(spacing: 40) {
            circleButton(icon: "xmark", color: .red) { perform(.delete) }
            circleButton(icon: "heart.fill", color: .pink) { perform(.like) }
            circleButton(icon: "checkmark", color: .green) { perform(.keep) }
        }
    }

    private func circleButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(color)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.background).shadow(radius: 4))
        }
        .buttonStyle(.plain)
        .disabled(isFlyingOut)
    }

    // MARK: - 统计条

    private var statsBar: some View {
        HStack(spacing: 16) {
            statItem("已删", processedCount.deleted, .red)
            statItem("已留", processedCount.kept, .green)
            statItem("喜欢", processedCount.liked, .pink)
            Spacer()
            Text("\(currentIndex + 1) / \(assets.count)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func statItem(_ label: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 空状态 / 完成

    private var emptyView: some View {
        ContentUnavailableView(
            "没有照片",
            systemImage: "photo.on.rectangle.angled",
            description: Text("源相册里没有照片，去「设置」选择要整理的相册")
        )
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("全部整理完啦！")
                .font(.title2.bold())
            Text("删除 \(processedCount.deleted) · 保留 \(processedCount.kept) · 喜欢 \(processedCount.liked)")
                .foregroundStyle(.secondary)
            Button("重新开始") { reload() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func reload() {
        assets = library.fetchAssets(sourceAlbumID: settings.sourceAlbumID)
        currentIndex = 0
        processedCount = (0, 0, 0)
        dragOffset = .zero
    }
}

// MARK: - 权限请求视图（多页共用）

struct PermissionView: View {
    @EnvironmentObject var library: PhotoLibraryManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            if library.authorizationStatus == .notDetermined {
                Text("PhotoClear 需要访问照片图库\n才能帮你整理照片")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("授权访问相册") {
                    Task { await library.requestPermission() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("相册访问被拒绝\n请到 系统设置 → 隐私与安全性 → 照片 中开启")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

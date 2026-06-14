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
    @Environment(\.scenePhase) private var scenePhase

    @State private var assets: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isFlyingOut = false
    @State private var isZoomed = false
    @State private var zoomScale: CGFloat = 1
    @State private var zoomAnchorScale: CGFloat = 1
    /// 开 = 移动（目标相册 + 移出源相册），关 = 复制（仅加入目标相册）
    @State private var moveMode = false
    @State private var errorMessage: String?
    @State private var processedCount = (deleted: 0, kept: 0, liked: 0)

    private let swipeThreshold: CGFloat = 110

    /// 是否允许"移动"：必须选了一个仍然存在的源相册。
    /// 整个图库没有可移除引用的源相册；相册列表没加载好或源相册已被删时也不能移动。
    private var canMove: Bool {
        !settings.sourceAlbumID.isEmpty && library.album(withID: settings.sourceAlbumID) != nil
    }

    /// 按"时钟方向"划分滑动区域：10点~2点=上滑喜欢，2点~6点=右滑保留，6点~10点=左滑删除
    private func swipeDirection(_ t: CGSize, threshold: CGFloat) -> SwipeAction? {
        let distance = (t.width * t.width + t.height * t.height).squareRoot()
        guard distance > threshold else { return nil }
        // 屏幕坐标 y 向下：3点=0°，6点=90°，9点=±180°，12点=-90°
        let angle = atan2(t.height, t.width) * 180 / .pi
        switch angle {
        case -150 ..< -40: return .like    // 上滑区 110°
        case -40 ..< 90: return .keep      // 右滑区上界上移 10°
        default: return .delete           // 其余为左滑
        }
    }

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
                // 文字与开关拆成两个独立工具栏项；.hidingGlassBackground() 去掉 26+ 的共享玻璃胶囊
                ToolbarItem(placement: .primaryAction) {
                    Text("移动")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .hidingGlassBackground()
                ToolbarItem(placement: .primaryAction) {
                    // 整库时不能移动：开关置灰，且即便之前开着也显示为关
                    Toggle("移动", isOn: Binding(
                        get: { moveMode && canMove },
                        set: { moveMode = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!canMove)
                }
                .hidingGlassBackground()
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .hidingGlassBackground()
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
        .onAppear {
            // 切回首页时刷新相册列表，让"移动"开关反映源相册的最新状态
            if library.isAuthorized { library.loadAlbums() }
        }
        .onChange(of: scenePhase) {
            // 从后台切回前台时刷新（相册可能在系统「照片」里被改动过）
            if scenePhase == .active, library.isAuthorized { library.loadAlbums() }
        }
        .overlay {
            if isZoomed, currentIndex < assets.count {
                zoomOverlay
            }
        }
    }

    /// 全貌查看：捏合可放大并保持；已放大时单击回正常，正常时单击退出
    private var zoomOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AssetImageView(
                asset: assets[currentIndex],
                targetSize: CGSize(width: 2400, height: 2400),
                fillMode: false
            )
            .scaleEffect(zoomScale)
        }
        .contentShape(Rectangle())
        .gesture(magnifyGesture)
        .onTapGesture { handleZoomTap() }
        .transition(.opacity)
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomScale = min(max(zoomAnchorScale * value.magnification, 1), 6)
            }
            .onEnded { _ in
                zoomAnchorScale = zoomScale
            }
    }

    private func handleZoomTap() {
        if zoomScale > 1.01 {
            withAnimation(.easeInOut(duration: 0.2)) { zoomScale = 1 }
            zoomAnchorScale = 1
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { isZoomed = false }
            zoomScale = 1
            zoomAnchorScale = 1
        }
    }

    // MARK: - 卡片堆

    private var cardStack: some View {
        VStack(spacing: 20) {
            statsBar

            if !canMove {
                moveDisabledHint
            }

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
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { isZoomed = true }
                        }
                        .gesture(dragGesture)
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
        let distance = (dragOffset.width * dragOffset.width + dragOffset.height * dragOffset.height).squareRoot()
        let opacity = min(Double(distance) / 110, 1)

        switch swipeDirection(dragOffset, threshold: 40) {
        case .delete:
            badge("删除", color: .red, angle: 12).opacity(opacity)
        case .keep:
            badge("保留", color: .green, angle: -12).opacity(opacity)
        case .like:
            badge("喜欢 ♥", color: .pink, angle: 0).opacity(opacity)
        case nil:
            EmptyView()
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
                guard !isFlyingOut, !isZoomed else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isFlyingOut, !isZoomed else { return }
                if let action = swipeDirection(value.translation, threshold: swipeThreshold) {
                    perform(action)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - 执行动作

    private func perform(_ action: SwipeAction) {
        let asset = assets[currentIndex]
        isFlyingOut = true

        // 卡片飞出
        withAnimation(.easeOut(duration: 0.3)) {
            switch action {
            case .delete: dragOffset = CGSize(width: -700, height: 0)
            case .keep: dragOffset = CGSize(width: 700, height: 0)
            case .like: dragOffset = CGSize(width: 0, height: -900)
            }
        }

        Task {
            do {
                // 右滑去向：设置了且不是源相册才需要移动
                let keepTarget = settings.keepAlbumID
                let needsKeepCopy = !keepTarget.isEmpty && keepTarget != settings.sourceAlbumID
                // 移动模式下，照片进了目标相册后要移出源相册
                var movedToTarget = false

                switch action {
                case .delete:
                    try await library.add(asset, toAlbumID: settings.deleteAlbumID)
                    movedToTarget = true
                    processedCount.deleted += 1
                case .keep:
                    if needsKeepCopy {
                        try await library.add(asset, toAlbumID: keepTarget)
                        movedToTarget = true
                    }
                    processedCount.kept += 1
                case .like:
                    // 喜欢 = 保留逻辑 + 额外存入喜欢相册
                    if needsKeepCopy {
                        try await library.add(asset, toAlbumID: keepTarget)
                    }
                    try await library.add(asset, toAlbumID: settings.likeAlbumID)
                    movedToTarget = true
                    processedCount.liked += 1
                }

                if moveMode && canMove && movedToTarget {
                    try await library.remove(asset, fromAlbumID: settings.sourceAlbumID)
                }
                try? await Task.sleep(for: .milliseconds(300))
                currentIndex += 1
            } catch {
                errorMessage = error.localizedDescription
            }
            // 不带动画归零，避免新卡片出现"飞回来"的视觉
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                dragOffset = .zero
            }
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

    // MARK: - 提示

    /// 整库时移动不可用的说明
    private var moveDisabledHint: some View {
        Label("整理整个图库时不能移动，去「设置」选「要处理的相册」即可开启", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        // 先刷新相册，避免源相册没加载好导致误抓整个图库
        if library.isAuthorized { library.loadAlbums() }
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

// MARK: - 工具栏玻璃背景

private extension ToolbarContent {
    /// iOS/macOS 26 会给工具栏项套一层共享玻璃胶囊背景，这里去掉它。
    /// 低于 26 的系统没有这层样式，原样返回。
    @ToolbarContentBuilder
    func hidingGlassBackground() -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

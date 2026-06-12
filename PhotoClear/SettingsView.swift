//
//  SettingsView.swift
//  PhotoClear
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var library: PhotoLibraryManager
    @EnvironmentObject var settings: AppSettings

    @State private var showNewAlbumDialog = false
    @State private var newAlbumName = ""
    @State private var errorMessage: String?
    @State private var albumPendingDelete: AlbumInfo?
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            Group {
                if !library.isAuthorized {
                    PermissionView()
                } else {
                    settingsList
                }
            }
            .navigationTitle("设置")
        }
        .task {
            if library.isAuthorized && library.albums.isEmpty {
                library.loadAlbums()
            }
        }
        .onChange(of: library.authorizationStatus) {
            if library.isAuthorized { library.loadAlbums() }
        }
    }

    private var settingsList: some View {
        List {
            Section {
                albumPicker(
                    title: "要处理的相册",
                    icon: "photo.stack",
                    color: .blue,
                    selection: $settings.sourceAlbumID,
                    emptyLabel: "整个图库"
                )
                albumPicker(
                    title: "删除相册（左滑去向）",
                    icon: "trash",
                    color: .red,
                    selection: $settings.deleteAlbumID,
                    emptyLabel: "未设置"
                )
                albumPicker(
                    title: "右滑去向",
                    icon: "checkmark.circle",
                    color: .green,
                    selection: $settings.keepAlbumID,
                    emptyLabel: "原相册（不移动）"
                )
                albumPicker(
                    title: "喜欢相册（上滑去向）",
                    icon: "heart",
                    color: .pink,
                    selection: $settings.likeAlbumID,
                    emptyLabel: "未设置"
                )
            } header: {
                HStack {
                    Text("整理设置")
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }

            Section {
                ForEach(library.albums) { album in
                    HStack {
                        Image(systemName: "rectangle.stack")
                            .foregroundStyle(.secondary)
                        Text(album.title)
                        Spacer()
                        Text("\(album.count)")
                            .foregroundStyle(.secondary)
                            .font(.footnote.monospacedDigit())
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            albumPendingDelete = album
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("我的相册（\(library.albums.count)）")
                    Spacer()
                    Button {
                        newAlbumName = ""
                        showNewAlbumDialog = true
                    } label: {
                        Label("新建", systemImage: "plus")
                            .font(.footnote)
                    }
                }
            }
        }
        .refreshable { library.loadAlbums() }
        .sheet(isPresented: $showHelp) { HelpSheet() }
        .alert("新建相册", isPresented: $showNewAlbumDialog) {
            TextField("相册名称", text: $newAlbumName)
            Button("创建") { createAlbum() }
            Button("取消", role: .cancel) {}
        }
        .alert(
            "删除「\(albumPendingDelete?.title ?? "")」？",
            isPresented: .init(
                get: { albumPendingDelete != nil },
                set: { if !$0 { albumPendingDelete = nil } }
            )
        ) {
            Button("是 全部删除", role: .destructive) { deletePendingAlbum() }
            Button("算了 留着", role: .cancel) {}
        } message: {
            Text("相册和相册内的全部照片（\(albumPendingDelete?.count ?? 0) 张）都会删除，请谨慎操作")
        }
        .alert("出错了", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func albumPicker(
        title: String,
        icon: String,
        color: Color,
        selection: Binding<String>,
        emptyLabel: String
    ) -> some View {
        Picker(selection: selection) {
            Text(emptyLabel).tag("")
            ForEach(library.albums) { album in
                Text(album.title).tag(album.id)
            }
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
        .pickerStyle(.menu)
    }

    private func createAlbum() {
        let name = newAlbumName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            do {
                try await library.createAlbum(named: name)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deletePendingAlbum() {
        guard let album = albumPendingDelete else { return }
        albumPendingDelete = nil
        Task {
            do {
                try await library.deleteAlbum(album)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - 帮助说明

private struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                helpRow(
                    icon: "arrow.left.circle.fill", color: .red,
                    title: "左滑 · 删除",
                    detail: "照片移入「删除相册」做标记，原图仍在图库。整理完去该相册一次性彻底删除，安全不误删。"
                )
                helpRow(
                    icon: "arrow.right.circle.fill", color: .green,
                    title: "右滑 · 保留",
                    detail: "默认原地不动；若设置了「右滑去向」，照片会同时存入该相册。"
                )
                helpRow(
                    icon: "arrow.up.circle.fill", color: .pink,
                    title: "上滑 · 喜欢",
                    detail: "在「保留」的基础上，额外存一份到「喜欢相册」。"
                )
                helpRow(
                    icon: "photo.stack", color: .blue,
                    title: "要处理的相册",
                    detail: "整理的照片来源，可选某个相册或整个图库。"
                )
            }
            .navigationTitle("滑动整理说明")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("知道了") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
    }

    private func helpRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

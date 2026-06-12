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
            Section("整理设置") {
                albumPicker(
                    title: "要处理的相册",
                    icon: "photo.stack",
                    color: .blue,
                    selection: $settings.sourceAlbumID,
                    allowWholeLibrary: true
                )
                albumPicker(
                    title: "删除相册（左滑去向）",
                    icon: "trash",
                    color: .red,
                    selection: $settings.deleteAlbumID,
                    allowWholeLibrary: false
                )
                albumPicker(
                    title: "喜欢相册（上滑去向）",
                    icon: "heart",
                    color: .pink,
                    selection: $settings.likeAlbumID,
                    allowWholeLibrary: false
                )
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
        .alert("新建相册", isPresented: $showNewAlbumDialog) {
            TextField("相册名称", text: $newAlbumName)
            Button("创建") { createAlbum() }
            Button("取消", role: .cancel) {}
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
        allowWholeLibrary: Bool
    ) -> some View {
        Picker(selection: selection) {
            if allowWholeLibrary {
                Text("整个图库").tag("")
            } else {
                Text("未设置").tag("")
            }
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
}

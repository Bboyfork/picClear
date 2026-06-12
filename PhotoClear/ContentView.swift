//
//  ContentView.swift
//  PhotoClear
//

import SwiftUI

struct ContentView: View {
    @StateObject private var library = PhotoLibraryManager()
    @StateObject private var settings = AppSettings()

    var body: some View {
        TabView {
            Tab("首页", systemImage: "rectangle.stack.badge.play") {
                SwipeView()
            }
            Tab("设置", systemImage: "gearshape") {
                SettingsView()
            }
            Tab("我的", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
        .environmentObject(library)
        .environmentObject(settings)
        .task {
            if library.isAuthorized {
                library.loadAlbums()
            } else {
                await library.requestPermission()
            }
        }
    }
}

#Preview {
    ContentView()
}

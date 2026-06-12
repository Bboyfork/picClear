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
            SwipeView()
                .tabItem { Label("首页", systemImage: "rectangle.stack.badge.play") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
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

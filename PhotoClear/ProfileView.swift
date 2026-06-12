//
//  ProfileView.swift
//  PhotoClear
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(.tint.opacity(0.6))
                Text("我的")
                    .font(.title2.bold())
                Text("敬请期待")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("我的")
        }
    }
}

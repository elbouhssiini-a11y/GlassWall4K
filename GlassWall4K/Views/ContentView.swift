//
//  ContentView.swift
//  GlassWall4K
//
//  Created by ELBOUHSSINI on 13/7/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .ios
    @State private var iosPath = NavigationPath()
    @State private var fourKPath = NavigationPath()
    @State private var favoritesPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    @Namespace private var iosTransition
    @Namespace private var fourKTransition
    @Namespace private var favoritesTransition

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $iosPath) {
                HomeView(namespace: iosTransition)
                    .navigationTitle("iOS 27")
                    .toolbarTitleDisplayMode(.inlineLarge)
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label(AppTab.ios.title, systemImage: AppTab.ios.systemImage)
            }
            .tag(AppTab.ios)

            NavigationStack(path: $fourKPath) {
                SearchView(namespace: fourKTransition)
                    .navigationTitle("Live Wallpapers")
                    .toolbarTitleDisplayMode(.inlineLarge)
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label(AppTab.fourK.title, systemImage: AppTab.fourK.systemImage)
            }
            .tag(AppTab.fourK)

            NavigationStack(path: $favoritesPath) {
                FavoritesView(namespace: favoritesTransition)
                    .navigationTitle("Favorites")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label(AppTab.favorites.title, systemImage: AppTab.favorites.systemImage)
            }
            .tag(AppTab.favorites)

            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
        }
        .tint(.accentColor)
        .onAppear {
            AdsManager.shared.notifyRootUIReady()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AdsManager.shared)
}

//
//  GlassWall4KApp.swift
//  GlassWall4K
//
//  Created by ELBOUHSSINI on 13/7/2026.
//

import SwiftUI

@main
struct GlassWall4KApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var didEnterBackground = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AdsManager.shared)
                .task {
                    await AdsManager.shared.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                didEnterBackground = true
                AdsManager.shared.handleDidEnterBackground()
            case .active:
                if didEnterBackground {
                    didEnterBackground = false
                    AdsManager.shared.handleBecameActive()
                }
            default:
                break
            }
        }
    }
}

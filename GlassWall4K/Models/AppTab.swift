//
//  AppTab.swift
//  GlassWall4K
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case ios
    case fourK
    case favorites
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ios: "iOS 27"
        case .fourK: "Live"
        case .favorites: "Favorites"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .ios: "iphone"
        case .fourK: "play.circle"
        case .favorites: "heart"
        case .settings: "gearshape"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .ios: "iphone"
        case .fourK: "play.circle.fill"
        case .favorites: "heart.fill"
        case .settings: "gearshape.fill"
        }
    }
}

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
        case .fourK: "4K"
        case .favorites: "Favorites"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .ios: "iphone"
        case .fourK: "4k.tv"
        case .favorites: "heart"
        case .settings: "gearshape"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .ios: "iphone"
        case .fourK: "4k.tv"
        case .favorites: "heart.fill"
        case .settings: "gearshape.fill"
        }
    }
}

//
//  GlassShadow.swift
//  GlassWall4K
//

import SwiftUI

enum GlassShadow {
    case card
    case chip
    case chipSelected
    case search
    case tabBar
    case button
    case soft

    var color: Color {
        switch self {
        case .card: .black.opacity(0.1)
        case .chip: .black.opacity(0.06)
        case .chipSelected: .black.opacity(0.1)
        case .search: .black.opacity(0.08)
        case .tabBar: .black.opacity(0.12)
        case .button: .black.opacity(0.08)
        case .soft: .black.opacity(0.08)
        }
    }

    var radius: CGFloat {
        switch self {
        case .card: 18
        case .chip: 10
        case .chipSelected: 14
        case .search: 16
        case .tabBar: 22
        case .button: 12
        case .soft: 16
        }
    }

    var y: CGFloat {
        switch self {
        case .card: 8
        case .chip: 4
        case .chipSelected: 6
        case .search: 6
        case .tabBar: 10
        case .button: 5
        case .soft: 8
        }
    }
}

extension View {
    func glassShadow(_ style: GlassShadow) -> some View {
        shadow(color: style.color, radius: style.radius, y: style.y)
    }
}

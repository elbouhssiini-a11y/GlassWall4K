//
//  WallpaperPresentation.swift
//  GlassWall4K
//
//  Presentation helpers for Wallpaper placeholders. No networking or image loading.
//

import SwiftUI

extension Wallpaper {
    /// Deterministic placeholder gradient for cards and detail previews.
    var placeholderGradient: [Color] {
        let palettes: [[Color]] = [
            [.purple, .indigo, .blue],
            [.orange, .pink],
            [.cyan, .blue],
            [.mint, .teal],
            [.green, .mint, .teal],
            [.black, .gray, .black],
            [.pink, .purple, .indigo],
            [.blue, .indigo, .black],
            [.red, .orange, .yellow],
            [.teal, .cyan, .blue],
            [.brown, .orange, .yellow],
            [.indigo, .blue, .cyan]
        ]

        let index = abs(id.utf8.reduce(0) { partial, byte in
            partial &+ Int(byte)
        }) % palettes.count
        return palettes[index]
    }
}

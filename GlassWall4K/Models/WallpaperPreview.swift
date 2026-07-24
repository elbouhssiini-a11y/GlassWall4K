//
//  WallpaperPreview.swift
//  GlassWall4K
//
//  UI placeholder model for composing screens. No networking or persistence.
//

import SwiftUI

struct WallpaperPreview: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let resolution: String
    let gradient: [Color]

    static let featured = WallpaperPreview(
        id: "aurora-dreams",
        title: "Aurora Dreams",
        subtitle: "Captured in stunning 4K detail",
        category: "Nature",
        resolution: "4K",
        gradient: [.purple, .indigo, .blue]
    )

    static let similar: [WallpaperPreview] = [
        WallpaperPreview(
            id: "sunset-bloom",
            title: "Sunset Bloom",
            subtitle: "Warm dusk tones",
            category: "Nature",
            resolution: "4K",
            gradient: [.orange, .pink]
        ),
        WallpaperPreview(
            id: "ocean-mist",
            title: "Ocean Mist",
            subtitle: "Soft coastal haze",
            category: "Minimal",
            resolution: "4K",
            gradient: [.cyan, .blue]
        ),
        WallpaperPreview(
            id: "neon-pulse",
            title: "Neon Pulse",
            subtitle: "Night city glow",
            category: "Abstract",
            resolution: "4K",
            gradient: [.mint, .teal]
        ),
        WallpaperPreview(
            id: "void-light",
            title: "Void Light",
            subtitle: "Deep space flares",
            category: "Space",
            resolution: "4K",
            gradient: [.purple, .indigo]
        ),
        WallpaperPreview(
            id: "ember-trail",
            title: "Ember Trail",
            subtitle: "Golden hour path",
            category: "Cars",
            resolution: "4K",
            gradient: [.yellow, .orange]
        )
    ]

    static let homePlaceholders: [WallpaperPreview] = [
        featured,
        WallpaperPreview(
            id: "forest-haze",
            title: "Forest Haze",
            subtitle: "Morning mist through the trees",
            category: "Nature",
            resolution: "4K",
            gradient: [.green, .mint, .teal]
        ),
        WallpaperPreview(
            id: "oled-dunes",
            title: "OLED Dunes",
            subtitle: "Deep black sandscapes",
            category: "AMOLED",
            resolution: "4K",
            gradient: [.black, .gray, .black]
        ),
        WallpaperPreview(
            id: "sakura-glow",
            title: "Sakura Glow",
            subtitle: "Soft neon petals",
            category: "Anime",
            resolution: "4K",
            gradient: [.pink, .purple, .indigo]
        ),
        WallpaperPreview(
            id: "midnight-run",
            title: "Midnight Run",
            subtitle: "Chrome under city lights",
            category: "Cars",
            resolution: "4K",
            gradient: [.blue, .indigo, .black]
        ),
        WallpaperPreview(
            id: "orbital-dust",
            title: "Orbital Dust",
            subtitle: "Quiet rings of starlight",
            category: "Space",
            resolution: "4K",
            gradient: [.indigo, .blue, .cyan]
        ),
        WallpaperPreview(
            id: "pixel-arena",
            title: "Pixel Arena",
            subtitle: "Electric arena haze",
            category: "Gaming",
            resolution: "4K",
            gradient: [.red, .orange, .yellow]
        ),
        WallpaperPreview(
            id: "soft-grain",
            title: "Soft Grain",
            subtitle: "Quiet color fields",
            category: "Minimal",
            resolution: "4K",
            gradient: [.gray, .secondary, .white]
        ),
        WallpaperPreview(
            id: "liquid-form",
            title: "Liquid Form",
            subtitle: "Flowing color geometry",
            category: "Abstract",
            resolution: "4K",
            gradient: [.teal, .cyan, .blue]
        ),
        WallpaperPreview(
            id: "golden-mane",
            title: "Golden Mane",
            subtitle: "Wildlife in soft light",
            category: "Animals",
            resolution: "4K",
            gradient: [.brown, .orange, .yellow]
        ),
        WallpaperPreview(
            id: "crimson-void",
            title: "Crimson Void",
            subtitle: "Dark AMOLED red flare",
            category: "AMOLED",
            resolution: "4K",
            gradient: [.black, .red, .black]
        ),
        WallpaperPreview(
            id: "alpine-light",
            title: "Alpine Light",
            subtitle: "Peaks above the clouds",
            category: "Nature",
            resolution: "4K",
            gradient: [.cyan, .mint, .green]
        )
    ]

    /// Placeholder favorites for UI composition only. No persistence.
    static let favoritePlaceholders: [WallpaperPreview] = Array(homePlaceholders.prefix(6))
}

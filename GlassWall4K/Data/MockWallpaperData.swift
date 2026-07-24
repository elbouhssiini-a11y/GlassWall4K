//
//  MockWallpaperData.swift
//  GlassWall4K
//

import Foundation

enum MockWallpaperData {
    static let categories: [Category] = Category.all

    static let wallpapers: [Wallpaper] = [
        make(
            id: "aurora-dreams",
            title: "Aurora Dreams",
            category: Category.iosWallpapers.name,
            featured: true,
            sortOrder: 1,
            daysAgo: 2
        ),
        make(
            id: "orbital-dust",
            title: "Orbital Dust",
            category: Category.iosWallpapers.name,
            featured: true,
            sortOrder: 2,
            daysAgo: 1
        ),
        make(
            id: "sakura-glow",
            title: "Sakura Glow",
            category: Category.iosWallpapers.name,
            featured: true,
            sortOrder: 3,
            daysAgo: 3
        ),
        make(
            id: "forest-haze",
            title: "Forest Haze",
            category: Category.iosWallpapers.name,
            sortOrder: 4,
            daysAgo: 5
        ),
        make(
            id: "oled-dunes",
            title: "OLED Dunes",
            category: Category.iosWallpapers.name,
            sortOrder: 5,
            daysAgo: 8
        ),
        make(
            id: "midnight-run",
            title: "Midnight Run",
            category: Category.iosWallpapers.name,
            sortOrder: 6,
            daysAgo: 12
        ),
        make(
            id: "pixel-arena",
            title: "Pixel Arena",
            category: Category.fourKWallpapers.name,
            sortOrder: 1,
            daysAgo: 6
        ),
        make(
            id: "soft-grain",
            title: "Soft Grain",
            category: Category.fourKWallpapers.name,
            sortOrder: 2,
            daysAgo: 10
        ),
        make(
            id: "liquid-form",
            title: "Liquid Form",
            category: Category.fourKWallpapers.name,
            sortOrder: 3,
            daysAgo: 4
        ),
        make(
            id: "golden-mane",
            title: "Golden Mane",
            category: Category.fourKWallpapers.name,
            sortOrder: 4,
            daysAgo: 7
        ),
        make(
            id: "crimson-void",
            title: "Crimson Void",
            category: Category.fourKWallpapers.name,
            sortOrder: 5,
            daysAgo: 9
        ),
        make(
            id: "alpine-light",
            title: "Alpine Light",
            category: Category.fourKWallpapers.name,
            sortOrder: 6,
            daysAgo: 11
        )
    ]

    private static func make(
        id: String,
        title: String,
        category: String,
        resolution: String = "4K",
        featured: Bool = false,
        sortOrder: Int = 9999,
        daysAgo: Int
    ) -> Wallpaper {
        let base = "https://example.com/wallpapers/\(id)"
        return Wallpaper(
            id: id,
            title: title,
            imageURL: URL(string: "\(base)/full.jpg")!,
            thumbnailURL: URL(string: "\(base)/thumb.jpg")!,
            category: category,
            resolution: resolution,
            featured: featured,
            sortOrder: sortOrder,
            createdAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        )
    }
}

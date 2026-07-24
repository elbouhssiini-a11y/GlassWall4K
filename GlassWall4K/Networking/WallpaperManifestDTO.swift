//
//  WallpaperManifestDTO.swift
//  GlassWall4K
//

import Foundation

struct WallpaperManifestDTO: Codable, Sendable {
    let categories: [CategoryDTO]
    let wallpapers: [WallpaperDTO]
}

struct CategoryDTO: Codable, Sendable {
    let id: String
    let name: String
    let icon: String

    func toDomain() -> Category {
        Category(id: id, name: name, icon: icon)
    }
}

struct WallpaperDTO: Codable, Sendable {
    let id: String
    let title: String
    let imageURL: URL
    let thumbnailURL: URL
    let category: String
    let resolution: String
    let featured: Bool
    let sortOrder: Int?
    let createdAt: Date

    func toDomain() -> Wallpaper {
        Wallpaper(
            id: id,
            title: title,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            category: category,
            resolution: resolution,
            featured: featured,
            sortOrder: sortOrder ?? 9999,
            createdAt: createdAt
        )
    }
}

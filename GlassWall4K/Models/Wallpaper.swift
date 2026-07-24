//
//  Wallpaper.swift
//  GlassWall4K
//

import Foundation

struct Wallpaper: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let imageURL: URL
    let thumbnailURL: URL
    let category: String
    let resolution: String
    let featured: Bool
    /// Catalog rank. Lower = higher (#1 first). Missing/legacy defaults to a large value.
    let sortOrder: Int
    let createdAt: Date
}

extension Array where Element == Wallpaper {
    func sortedByCatalogOrder() -> [Wallpaper] {
        sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

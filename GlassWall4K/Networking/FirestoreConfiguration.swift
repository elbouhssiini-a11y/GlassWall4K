//
//  FirestoreConfiguration.swift
//  GlassWall4K
//

import Foundation

enum FirestoreConfiguration {
    static let projectID = "glasswall4k"
    static let wallpapersCollection = "wallpapers"

    static var wallpapersListURL: URL {
        URL(
            string:
                "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents/\(wallpapersCollection)?pageSize=200"
        )!
    }
}

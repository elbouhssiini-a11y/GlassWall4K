//
//  FirebaseStorageConfiguration.swift
//  GlassWall4K
//

import Foundation

enum FirebaseStorageConfiguration {
    static let projectId = "glasswall4k"
    static let storageBucket = "glasswall4k.firebasestorage.app"
    static let manifestObjectPath = "manifest.json"

    /// Public download URL for an object stored in Firebase Storage.
    static func downloadURL(for objectPath: String) -> URL {
        let encodedPath = objectPath
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?
            .replacingOccurrences(of: "/", with: "%2F")
            ?? objectPath

        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(storageBucket)/o/\(encodedPath)?alt=media")!
    }

    static var manifestURL: URL {
        downloadURL(for: manifestObjectPath)
    }
}

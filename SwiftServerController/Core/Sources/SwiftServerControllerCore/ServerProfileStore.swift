//
//  ServerProfileStore.swift
//  SwiftServerControllerCore
//
//  Created by hjy_666 on 2026/10/7.
//

import Foundation

public struct ServerProfileStore: Sendable {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> [MinecraftServerProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([MinecraftServerProfile].self, from: data)
    }

    public func save(_ profiles: [MinecraftServerProfile]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        let data = try JSONEncoder().encode(profiles)
        try data.write(to: fileURL, options: .atomic)
    }
}

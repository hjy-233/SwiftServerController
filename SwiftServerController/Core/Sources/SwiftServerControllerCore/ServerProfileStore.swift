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

    public init() throws {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true,
        )

        fileURL = applicationSupportURL
            .appendingPathComponent("SwiftServerController", isDirectory: true)
            .appendingPathComponent("servers.json")
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

    public func add(_ profile: MinecraftServerProfile) throws {
        var profiles = try load()
        profiles.append(profile)
        try save(profiles)
    }

    public func dataDirectory(for id: UUID) -> URL {
        fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("Servers", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    public func prepareDataDirectory(
        for id: UUID,
        serverJarURL: URL,
        eulaAccepted: Bool
    ) throws -> URL {
        guard eulaAccepted else {
            throw ContainerClientError.eulaNotAccepted
        }

        let dataDirectory = dataDirectory(for: id)
        try FileManager.default.createDirectory(
            at: dataDirectory,
            withIntermediateDirectories: true,
        )

        try FileManager.default.copyItem(
            at: serverJarURL,
            to: dataDirectory.appendingPathComponent("server.jar"),
        )

        try "eula=true\n".write(
            to: dataDirectory.appendingPathComponent("eula.txt"),
            atomically: true,
            encoding: .utf8,
        )

        return dataDirectory
    }
}

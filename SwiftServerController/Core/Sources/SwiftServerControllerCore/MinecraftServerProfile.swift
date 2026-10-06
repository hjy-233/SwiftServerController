//
//  MinecraftServerProfile.swift
//  SwiftServerControllerCore
//
//  Created by hjy_666 on 2026/10/6.
//

import Foundation

public struct MinecraftServerProfile: Identifiable, Codable {
    public let id: UUID
    public let version: String
    public let dataDirectory: URL

    public var name: String
    public var port: UInt16
    public var memoryInMB: Int

    public init(
        id: UUID,
        version: String,
        dataDirectory: URL,
        name: String,
        port: UInt16,
        memoryInMB: Int,
    ) {
        self.id = id
        self.version = version
        self.dataDirectory = dataDirectory
        self.name = name
        self.port = port
        self.memoryInMB = memoryInMB
    }
}

//
//  ContainerClient.swift
//  SwiftServerControllerCore
//
//  Created by hjy_666 on 2026/10/5.
//

import Foundation

public enum ContainerClientError: LocalizedError {
    case commandFailed(exitCode: Int32, message: String)
    case invalidOutput

    public var errorDescription: String? {
        switch self {
        case let .commandFailed(exitCode, message):
            if message.isEmpty {
                return "container command failed with exit code \(exitCode)."
            }

            return "container command failed with exit code \(exitCode): \(message)"
        case .invalidOutput:
            return "container command returned invalid UTF-8 output."
        }
    }
}

public struct ContainerClient: Sendable {
    private let executableURL: URL

    public init() {
        executableURL = URL(fileURLWithPath: "/usr/local/bin/container")
    }

    init(executableURL: URL) {
        self.executableURL = executableURL
    }

    private func executeSync(arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let decodedOutput = String(bytes: data, encoding: .utf8) else {
            throw ContainerClientError.invalidOutput
        }

        let output = decodedOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw ContainerClientError.commandFailed(
                exitCode: process.terminationStatus,
                message: output,
            )
        }

        return output
    }

    private func execute(arguments: [String]) async throws -> String {
        let task = Task.detached {
            try executeSync(arguments: arguments)
        }
        return try await task.value
    }

    public func version() async throws -> String {
        try await execute(arguments: ["--version"])
    }

    public func listContainers() async throws -> [ContainerInfo] {
        let output = try await execute(arguments: [
            "list",
            "--all",
            "--format",
            "json",
        ])

        return try JSONDecoder().decode([ContainerInfo].self, from: Data(output.utf8))
    }

    public func startContainer(id: String) async throws {
        _ = try await execute(arguments: ["start", id])
    }

    public func stopContainer(id: String) async throws {
        _ = try await execute(arguments: ["stop", id])
    }

    public func createMinecraftContainer(profile: MinecraftServerProfile) async throws {
        _ = try await execute(arguments: [
            "create",
            "--name",
            "minecraft-\(profile.id)",
            "--memory",
            "\(profile.memoryInMB)M",
            "--publish",
            "\(profile.port):25565",
            "--mount",
            "type=bind,source=\(profile.dataDirectory.path),target=/server",
            "docker.io/library/eclipse-temurin:25-jre",
            "java",
            "-Xmx\(profile.memoryInMB)M",
            "-jar",
            "/server/server.jar",
            "nogui",
        ])
    }
}

public struct ContainerInfo: Decodable, Identifiable {
    public let status: String
    public let configuration: Configuration

    public var id: String {
        configuration.id
    }

    public struct Configuration: Decodable {
        public let id: String
        public let image: Image
    }

    public struct Image: Decodable {
        public let reference: String
    }
}

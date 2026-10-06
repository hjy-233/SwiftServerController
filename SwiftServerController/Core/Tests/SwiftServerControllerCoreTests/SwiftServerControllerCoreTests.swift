import Foundation
@testable import SwiftServerControllerCore
import Testing

@Test func versionReturnsCommandOutput() async throws {
    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/bin/echo"))

    #expect(try await client.version() == "--version")
}

@Test func versionThrowsWhenCommandFails() async {
    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/usr/bin/false"))

    await #expect(throws: ContainerClientError.self) {
        try await client.version()
    }
}

@Test func containerInfoDecode() throws {
    let json = """
    [
      {
        "status": "running",
        "configuration": {
          "id": "minecraft-test",
          "image": {
            "reference": "docker.io/library/eclipse-temurin:21"
          }
        },
        "networks": [],
        "startedDate": null
      }
    ]
    """

    let containers = try JSONDecoder().decode(
        [ContainerInfo].self,
        from: Data(json.utf8)
    )

    #expect(containers.count == 1)
    #expect(containers[0].id == "minecraft-test")
    #expect(containers[0].status == "running")
    #expect(containers[0].configuration.image.reference == "docker.io/library/eclipse-temurin:21")
}

@Test func emptyContainerInfoDecode() throws {
    let containers = try JSONDecoder().decode(
        [ContainerInfo].self,
        from: Data("[]".utf8)
    )

    #expect(containers.isEmpty)
}

@Test func createMinecraftContainerThrowsWhenServerJarIsMissing() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/bin/echo"))

    await #expect(throws: ContainerClientError.serverJarNotFound) {
        try await client.createMinecraftContainer(profile: makeProfile(dataDirectory: directory))
    }
}

@Test func createMinecraftContainerThrowsWhenEULAIsMissing() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data().write(to: directory.appendingPathComponent("server.jar"))

    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/bin/echo"))

    await #expect(throws: ContainerClientError.eulaNotAccepted) {
        try await client.createMinecraftContainer(profile: makeProfile(dataDirectory: directory))
    }
}

@Test func createMinecraftContainerThrowsWhenEULAIsFalse() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data().write(to: directory.appendingPathComponent("server.jar"))
    try "eula=false".write(
        to: directory.appendingPathComponent("eula.txt"),
        atomically: true,
        encoding: .utf8
    )

    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/bin/echo"))

    await #expect(throws: ContainerClientError.eulaNotAccepted) {
        try await client.createMinecraftContainer(profile: makeProfile(dataDirectory: directory))
    }
}

@Test func createMinecraftContainerAcceptsSpacedEULAProperty() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data().write(to: directory.appendingPathComponent("server.jar"))
    try "eula = true".write(
        to: directory.appendingPathComponent("eula.txt"),
        atomically: true,
        encoding: .utf8
    )

    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/bin/echo"))

    try await client.createMinecraftContainer(profile: makeProfile(dataDirectory: directory))
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func makeProfile(dataDirectory: URL) -> MinecraftServerProfile {
    MinecraftServerProfile(
        id: UUID(),
        version: "26.3",
        dataDirectory: dataDirectory,
        name: "Test Server",
        port: 25565,
        memoryInMB: 4096
    )
}

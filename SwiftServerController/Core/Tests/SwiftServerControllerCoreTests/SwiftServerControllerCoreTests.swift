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
        from: Data(json.utf8),
    )

    #expect(containers.count == 1)
    #expect(containers[0].id == "minecraft-test")
    #expect(containers[0].status == "running")
    #expect(containers[0].configuration.image.reference == "docker.io/library/eclipse-temurin:21")
}

@Test func emptyContainerInfoDecode() throws {
    let containers = try JSONDecoder().decode(
        [ContainerInfo].self,
        from: Data("[]".utf8),
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
        encoding: .utf8,
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
        encoding: .utf8,
    )

    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/bin/echo"))

    try await client.createMinecraftContainer(profile: makeProfile(dataDirectory: directory))
}

@Test func minecraftContainerUsesServerDirectoryAsWorkingDirectory() throws {
    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/bin/echo"))
    let profile = makeProfile(dataDirectory: URL(fileURLWithPath: "/server-data"))
    let arguments = client.minecraftContainerArguments(profile: profile)
    let workdirIndex = try #require(arguments.firstIndex(of: "--workdir"))

    #expect(arguments[workdirIndex + 1] == "/server")
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
        memoryInMB: 4096,
    )
}

@Test func loadReturnsEmptyArrayWhenFileDoesNotExist() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appendingPathComponent("profiles.json")
    let store = ServerProfileStore(fileURL: fileURL)

    let profiles = try store.load()

    #expect(profiles.isEmpty)
}

@Test func loadReturnsProfilesWhenFileExists() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appendingPathComponent("profiles.json")
    let expectedProfile = makeProfile(dataDirectory: directory)
    try JSONEncoder().encode([expectedProfile]).write(to: fileURL)
    let store = ServerProfileStore(fileURL: fileURL)

    let profiles = try store.load()
    let profile = try #require(profiles.first)

    #expect(profiles.count == 1)
    #expect(profile.id == expectedProfile.id)
    #expect(profile.version == expectedProfile.version)
    #expect(profile.dataDirectory == expectedProfile.dataDirectory)
    #expect(profile.name == expectedProfile.name)
    #expect(profile.port == expectedProfile.port)
    #expect(profile.memoryInMB == expectedProfile.memoryInMB)
}

@Test func saveWritesProfilesToFile() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory
        .appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent("profiles.json")
    let profile = makeProfile(dataDirectory: directory)
    let store = ServerProfileStore(fileURL: fileURL)

    try store.save([profile])

    let profiles = try store.load()
    #expect(profiles.count == 1)
    #expect(profiles.first?.id == profile.id)
}

@Test func addAppendsProfileWithoutReplacingExistingProfiles() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appendingPathComponent("profiles.json")
    let firstProfile = makeProfile(dataDirectory: directory)
    let secondProfile = makeProfile(dataDirectory: directory)
    let store = ServerProfileStore(fileURL: fileURL)
    try store.save([firstProfile])

    try store.add(secondProfile)

    let profileIDs = try Set(store.load().map(\.id))
    #expect(profileIDs == [firstProfile.id, secondProfile.id])
}

@Test func dataDirectoryUsesServersFolderAndProfileID() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ServerProfileStore(fileURL: directory.appendingPathComponent("servers.json"))
    let id = UUID()
    let expectedURL = directory
        .appendingPathComponent("Servers", isDirectory: true)
        .appendingPathComponent(id.uuidString, isDirectory: true)

    let dataDirectory = store.dataDirectory(for: id)

    #expect(dataDirectory == expectedURL)
    #expect(!FileManager.default.fileExists(atPath: dataDirectory.path))
}

@Test func prepareDataDirectoryCopiesServerJarWithoutRemovingSource() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ServerProfileStore(fileURL: directory.appendingPathComponent("servers.json"))
    let id = UUID()
    let sourceJarURL = directory.appendingPathComponent("source.jar")
    let sourceData = Data("server jar".utf8)
    try sourceData.write(to: sourceJarURL)

    let preparedDirectory = try store.prepareDataDirectory(for: id, serverJarURL: sourceJarURL)

    let copiedJarURL = preparedDirectory.appendingPathComponent("server.jar")
    #expect(preparedDirectory == store.dataDirectory(for: id))
    #expect(FileManager.default.fileExists(atPath: sourceJarURL.path))
    #expect(try Data(contentsOf: copiedJarURL) == sourceData)
}

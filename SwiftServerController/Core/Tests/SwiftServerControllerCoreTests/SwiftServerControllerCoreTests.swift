import Foundation
@testable import SwiftServerControllerCore
import Testing

@Test func versionReturnsCommandOutput() throws {
    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/bin/echo"))

    #expect(try client.version() == "--version")
}

@Test func versionThrowsWhenCommandFails() {
    let client = ContainerClient(executableURL: URL(fileURLWithPath: "/usr/bin/false"))

    #expect(throws: ContainerClientError.self) {
        try client.version()
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

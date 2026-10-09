//
//  ContentView.swift
//  SwiftServerController
//
//  Created by hjy_666 on 2026/10/5.
//

import SwiftServerControllerCore
import SwiftUI

struct ContentView: View {
    @State private var version = "Unknown"
    @State private var containers = [ContainerInfo]()
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isShowingCreateServer = false
    @State private var profiles = [MinecraftServerProfile]()

    private func reload() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleContainer(_ container: ContainerInfo) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let client = ContainerClient()

            if container.status == "running" {
                try await client.stopContainer(id: container.id)
            } else {
                try await client.startContainer(id: container.id)
            }

            containers = try await client.listContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func profile(for container: ContainerInfo) -> MinecraftServerProfile? {
        profiles.first {
            container.id == "minecraft-\($0.id)"
        }
    }

    private func refresh() async throws {
        let client = ContainerClient()
        let store = try ServerProfileStore()

        version = try await client.version()
        containers = try await client.listContainers()
        profiles = try store.load()
    }

    var body: some View {
        VStack {
            Text("版本:\(version)")
            Group {
                if isLoading {
                    ProgressView("正在加载")
                } else if let errorMessage {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage),
                    )
                } else if containers.isEmpty {
                    ContentUnavailableView(
                        "暂无容器",
                        systemImage: "shippingbox",
                    )
                } else {
                    List(containers) { container in
                        let serverProfile = profile(for: container)

                        HStack {
                            VStack(alignment: .leading) {
                                Text(serverProfile?.name ?? container.id)

                                if serverProfile != nil {
                                    Text(container.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(container.configuration.image.reference)
                            Text(container.status)

                            Button(container.status == "running" ? "停止" : "启动") {
                                Task {
                                    await toggleContainer(container)
                                }
                            }
                        }
                    }
                }
            }
            Button("刷新") {
                Task {
                    await reload()
                }
            }
            .disabled(isLoading)
        }
        .padding()
        .toolbar {
            Button {
                isShowingCreateServer = true
            } label: {
                Label("添加服务器", systemImage: "plus")
            }
        }
        .sheet(
            isPresented: $isShowingCreateServer,
            onDismiss: {
                Task {
                    await reload()
                }
            },
            content: {
                CreateServerView()
            }
        )
        .task {
            await reload()
        }
    }
}

#Preview {
    ContentView()
}

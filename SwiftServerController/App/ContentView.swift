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
    @State private var profilePendingDeletion: MinecraftServerProfile?

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

    private func container(for profile: MinecraftServerProfile) -> ContainerInfo? {
        containers.first {
            $0.id == "minecraft-\(profile.id)"
        }
    }

    private func deleteServer(
        _ profile: MinecraftServerProfile,
        container: ContainerInfo?
    ) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let client = ContainerClient()

            if let container {
                if container.status == "running" {
                    try await client.stopContainer(id: container.id)
                }

                try await client.deleteContainer(id: container.id)
            }

            try ServerProfileStore().remove(id: profile.id)

            try await refresh()
        } catch {
            errorMessage = error.localizedDescription
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
                } else if profiles.isEmpty {
                    ContentUnavailableView(
                        "暂无服务器",
                        systemImage: "shippingbox",
                    )
                } else {
                    List(profiles) { profile in
                        let container = container(for: profile)

                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name)

                                if let container {
                                    Text(container.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("容器不存在")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let container {
                                Text(container.configuration.image.reference)
                                Text(container.status == "running" ? "运行中" : "已停止")

                                Button(container.status == "running" ? "停止" : "启动") {
                                    Task {
                                        await toggleContainer(container)
                                    }
                                }
                            }

                            Button(role: .destructive) {
                                profilePendingDeletion = profile
                            } label: {
                                Label("删除服务器", systemImage: "trash")
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
        .alert(
            "删除服务器？",
            isPresented: Binding(
                get: { profilePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        profilePendingDeletion = nil
                    }
                }
            ),
            presenting: profilePendingDeletion
        ) { profile in
            Button("删除", role: .destructive) {
                profilePendingDeletion = nil
                Task {
                    await deleteServer(
                        profile,
                        container: container(for: profile)
                    )
                }
            }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("容器和服务器记录将被删除，服务器文件会保留。")
        }
        .task {
            await reload()
        }
    }
}

#Preview {
    ContentView()
}

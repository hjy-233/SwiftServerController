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
    @State private var selectedProfileID: MinecraftServerProfile.ID?

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

    private var selectedProfile: MinecraftServerProfile? {
        profiles.first {
            $0.id == selectedProfileID
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

        if !profiles.contains(where: { $0.id == selectedProfileID }) {
            selectedProfileID = profiles.first?.id
        }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if isLoading, profiles.isEmpty {
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
                    List(profiles, selection: $selectedProfileID) { profile in
                        let container = container(for: profile)

                        VStack(alignment: .leading) {
                            Text(profile.name)

                            Text(container?.status == "running" ? "运行中" : container == nil ? "容器不存在" : "已停止")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(profile.id)
                    }
                }
            }
            .navigationTitle("服务器")
        } detail: {
            if let profile = selectedProfile {
                let container = container(for: profile)

                Form {
                    Section("服务器") {
                        LabeledContent("名称", value: profile.name)
                        LabeledContent("版本", value: profile.version)
                        LabeledContent("端口", value: String(profile.port))
                        LabeledContent("内存", value: "\(profile.memoryInMB) MB")
                    }

                    Section("容器") {
                        if let container {
                            LabeledContent(
                                "状态",
                                value: container.status == "running" ? "运行中" : "已停止"
                            )
                            LabeledContent(
                                "镜像",
                                value: container.configuration.image.reference
                            )
                        } else {
                            LabeledContent("状态", value: "容器不存在")
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView(
                    "未选择服务器",
                    systemImage: "sidebar.left",
                    description: Text("请从侧边栏选择一个服务器。")
                )
            }
        }
        .toolbar {
            Button {
                isShowingCreateServer = true
            } label: {
                Label("添加服务器", systemImage: "plus")
            }

            if let profile = selectedProfile {
                if let container = container(for: profile) {
                    Button {
                        Task {
                            await toggleContainer(container)
                        }
                    } label: {
                        Label(
                            container.status == "running" ? "停止" : "启动",
                            systemImage: container.status == "running" ? "stop.fill" : "play.fill"
                        )
                    }
                    .disabled(isLoading)
                }

                Menu {
                    Button(role: .destructive) {
                        profilePendingDeletion = profile
                    } label: {
                        Label("删除服务器", systemImage: "trash")
                    }
                } label: {
                    Label("更多操作", systemImage: "ellipsis.circle")
                }
                .disabled(isLoading)
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

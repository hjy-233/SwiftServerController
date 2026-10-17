//
//  ContentView.swift
//  SwiftServerController
//
//  Created by hjy_666 on 2026/10/5.
//

import Foundation
import SwiftServerControllerCore
import SwiftUI

private enum ServerPage: Hashable {
    case overview
    case console
}

struct ContentView: View {
    @State private var version = "Unknown"
    @State private var containers = [ContainerInfo]()
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isShowingCreateServer = false
    @State private var profiles = [MinecraftServerProfile]()
    @State private var profilePendingDeletion: MinecraftServerProfile?
    @State private var selectedProfileID: MinecraftServerProfile.ID?
    @State private var selectedStats: ContainerStats?
    @State private var selectedCPUUsagePercent: Double?
    @State private var isLoadingStats = false
    @State private var statsErrorMessage: String?
    @State private var selectedPage = ServerPage.overview

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

                switch selectedPage {
                case .overview:
                    ServerOverviewView(
                        profile: profile,
                        container: container,
                        stats: selectedStats,
                        cpuUsagePercent: selectedCPUUsagePercent,
                        isLoadingStats: isLoadingStats,
                        statsErrorMessage: statsErrorMessage
                    )
                case .console:
                    ServerConsoleView(profile: profile)
                }
            } else {
                ContentUnavailableView(
                    "未选择服务器",
                    systemImage: "sidebar.left",
                    description: Text("请从侧边栏选择一个服务器。")
                )
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    isShowingCreateServer = true
                } label: {
                    Label("添加服务器", systemImage: "plus")
                }
            }

            if let profile = selectedProfile {
                if let container = container(for: profile) {
                    ToolbarItem {
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
                }

                ToolbarItem {
                    Menu {
                        Button(role: .destructive) {
                            profilePendingDeletion = profile
                        } label: {
                            Label("删除服务器", systemImage: "trash")
                        }
                        Button {
                            NSWorkspace.shared.open(profile.dataDirectory)
                        } label: {
                            Label("打开文件夹", systemImage: "folder")
                        }
                    } label: {
                        Label("更多操作", systemImage: "ellipsis.circle")
                    }
                    .disabled(isLoading)
                }
            }

            if selectedProfile != nil {
                ToolbarItem(placement: .principal) {
                    Picker("页面", selection: $selectedPage) {
                        Text("概览").tag(ServerPage.overview)
                        Text("控制台").tag(ServerPage.console)
                    }
                .pickerStyle(.segmented)
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
        .task(id: selectedStatsTaskID) {
            await monitorSelectedStats()
        }
    }
}

private extension ContentView {
    var selectedStatsTaskID: String? {
        guard selectedPage == .overview,
              let profile = selectedProfile,
              let container = container(for: profile)
        else {
            return nil
        }

        return "\(container.id):\(container.status)"
    }

    func cpuUsagePercent(
        currentUsageUsec: UInt64?,
        previousUsageUsec: UInt64?,
        elapsedSeconds: TimeInterval?
    ) -> Double? {
        guard let currentUsageUsec,
              let previousUsageUsec,
              currentUsageUsec >= previousUsageUsec,
              let elapsedSeconds,
              elapsedSeconds > 0
        else {
            return nil
        }

        return Double(currentUsageUsec - previousUsageUsec) / elapsedSeconds / 1_000_000 * 100
    }

    func monitorSelectedStats() async {
        selectedStats = nil
        selectedCPUUsagePercent = nil
        statsErrorMessage = nil

        guard let profile = selectedProfile,
              let container = container(for: profile),
              selectedPage == .overview,
              container.status == "running"
        else {
            isLoadingStats = false
            return
        }

        isLoadingStats = true
        var previousSample: (usageUsec: UInt64, date: Date)?

        while !Task.isCancelled {
            do {
                let stats = try await ContainerClient().stats(id: container.id)
                let sampleDate = Date()

                guard !Task.isCancelled,
                      selectedProfileID == profile.id,
                      self.container(for: profile)?.status == "running"
                else {
                    return
                }

                selectedCPUUsagePercent = cpuUsagePercent(
                    currentUsageUsec: stats?.cpuUsageUsec,
                    previousUsageUsec: previousSample?.usageUsec,
                    elapsedSeconds: previousSample.map { sampleDate.timeIntervalSince($0.date) }
                )

                previousSample = stats.map { ($0.cpuUsageUsec, sampleDate) }
                selectedStats = stats
                statsErrorMessage = nil
                isLoadingStats = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      selectedProfileID == profile.id,
                      self.container(for: profile)?.status == "running"
                else {
                    return
                }

                statsErrorMessage = error.localizedDescription
                isLoadingStats = false
            }

            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
        }
    }
}

#Preview {
    ContentView()
}

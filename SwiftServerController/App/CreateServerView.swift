//
//  CreateServerView.swift
//  SwiftServerController
//
//  Created by hjy_666 on 2026/10/6.
//

import SwiftServerControllerCore
import SwiftUI
import UniformTypeIdentifiers

struct CreateServerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var serverName = ""
    @State private var serverVersion = "26.3"
    @State private var serverPort: UInt16 = 25565
    @State private var serverMemory = 4096
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var hasAcceptedEULA = false
    @State private var serverJarURL: URL?
    @State private var isSelectingServerJar = false

    private func createServer() async {
        let trimmedName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "请输入服务器名称。"
            return
        }

        guard let serverJarURL else {
            errorMessage = "请选择 server.jar。"
            return
        }

        guard hasAcceptedEULA else {
            errorMessage = ContainerClientError.eulaNotAccepted.localizedDescription
            return
        }

        isCreating = true
        errorMessage = nil

        defer {
            isCreating = false
        }

        do {
            let id = UUID()
            let store = try ServerProfileStore()
            let dataDirectory = try store.prepareDataDirectory(
                for: id,
                serverJarURL: serverJarURL,
                eulaAccepted: hasAcceptedEULA
            )
            let profile = MinecraftServerProfile(
                id: id,
                version: serverVersion.trimmingCharacters(in: .whitespacesAndNewlines),
                dataDirectory: dataDirectory,
                name: trimmedName,
                port: serverPort,
                memoryInMB: serverMemory
            )

            try await ContainerClient().createMinecraftContainer(profile: profile)
            try store.add(profile)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var body: some View {
        Form {
            TextField("名称", text: $serverName)
            TextField("版本", text: $serverVersion)

            LabeledContent("服务器 JAR") {
                HStack {
                    Text(serverJarURL?.lastPathComponent ?? "未选择")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("选择…") {
                        isSelectingServerJar = true
                    }
                }
            }

            TextField("端口", value: $serverPort, format: .number)
            TextField("内存 (MB)", value: $serverMemory, format: .number)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            Toggle("我已阅读并同意 Minecraft EULA", isOn: $hasAcceptedEULA)
        }
        .disabled(isCreating)
        .interactiveDismissDisabled(isCreating)
        .fileImporter(
            isPresented: $isSelectingServerJar,
            allowedContentTypes: [UTType(filenameExtension: "jar") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result {
                serverJarURL = urls.first
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
                .disabled(isCreating)
            }

            ToolbarItem(placement: .primaryAction) {
                if isCreating {
                    ProgressView()
                } else {
                    Button("创建") {
                        Task {
                            await createServer()
                        }
                    }
                    .disabled(
                        serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || serverVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || serverJarURL == nil
                            || serverMemory <= 0
                            || !hasAcceptedEULA
                    )
                }
            }
        }
    }
}

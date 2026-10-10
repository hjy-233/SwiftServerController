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
    @State private var serverDirectory: URL?
    @State private var serverPort: UInt16 = 25565
    @State private var serverMemory = 4096
    @State private var isSelectingDirectory = false
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var hasAcceptedEULA = false

    private func createServer() async {
        let trimmedName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "请输入服务器名称。"
            return
        }

        guard let serverDirectory else {
            errorMessage = "请选择服务器目录。"
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

        let profile = MinecraftServerProfile(
            id: UUID(),
            version: serverVersion.trimmingCharacters(in: .whitespacesAndNewlines),
            dataDirectory: serverDirectory,
            name: trimmedName,
            port: serverPort,
            memoryInMB: serverMemory
        )

        do {
            try await ContainerClient().createMinecraftContainer(profile: profile)
            try ServerProfileStore().add(profile)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var body: some View {
        Form {
            TextField("名称", text: $serverName)
            TextField("版本", text: $serverVersion)

            LabeledContent("服务器目录") {
                HStack {
                    Text(serverDirectory?.path ?? "未选择")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("选择…") {
                        isSelectingDirectory = true
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
            isPresented: $isSelectingDirectory,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                serverDirectory = urls.first
                errorMessage = nil
            case let .failure(error):
                let cocoaError = error as NSError
                if cocoaError.domain != NSCocoaErrorDomain || cocoaError.code != NSUserCancelledError {
                    errorMessage = error.localizedDescription
                }
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
                            || serverDirectory == nil
                            || serverMemory <= 0
                            || !hasAcceptedEULA
                    )
                }
            }
        }
    }
}

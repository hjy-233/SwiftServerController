//
//  CreateServerView.swift
//  SwiftServerController
//
//  Created by hjy_666 on 2026/10/6.
//

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
        }
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
            }
        }
    }
}

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
                        HStack {
                            Text(container.id)
                            Text(container.configuration.image.reference)
                            Text(container.status)
                        }
                    }
                }
            }
            Button("Check") {
                Task {
                    isLoading = true
                    errorMessage = nil
                    do {
                        version = try await ContainerClient().version()
                        containers = try await ContainerClient().listContainers()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isLoading = false
                }
            }.disabled(isLoading)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

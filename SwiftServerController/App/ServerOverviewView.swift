//
//  ServerOverviewView.swift
//  SwiftServerController
//
//  Created by hjy_666 on 2026/10/11.
//

import Foundation
import SwiftServerControllerCore
import SwiftUI

struct ServerOverviewView: View {
    let profile: MinecraftServerProfile
    let container: ContainerInfo?
    let stats: ContainerStats?
    let cpuUsagePercent: Double?
    let isLoadingStats: Bool
    let statsErrorMessage: String?

    private func formattedBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(clamping: bytes),
            countStyle: .memory
        )
    }

    var body: some View {
        Form {
            Section("服务器") {
                LabeledContent("名称", value: profile.name)
                LabeledContent("版本", value: profile.version)
                LabeledContent("端口", value: String(profile.port))
                LabeledContent("内存", value: "\(profile.memoryInMB) MB")
            }

            Section("容器") {
                if let container {
                    LabeledContent("ID", value: container.id)
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

            Section("当前资源") {
                if isLoadingStats {
                    ProgressView("正在读取")
                } else if let statsErrorMessage {
                    Text(statsErrorMessage)
                        .foregroundStyle(.red)
                } else if let stats {
                    LabeledContent(
                        "CPU",
                        value: cpuUsagePercent.map { String(format: "%.2f%%", $0) } ?? "正在计算"
                    )
                    LabeledContent(
                        "内存",
                        value: "\(formattedBytes(stats.memoryUsageBytes)) / \(formattedBytes(stats.memoryLimitBytes))"
                    )
                    LabeledContent("进程", value: String(stats.numProcesses))
                    LabeledContent("网络接收", value: formattedBytes(stats.networkRxBytes))
                    LabeledContent("网络发送", value: formattedBytes(stats.networkTxBytes))
                    LabeledContent("块读取", value: formattedBytes(stats.blockReadBytes))
                    LabeledContent("块写入", value: formattedBytes(stats.blockWriteBytes))
                } else if container?.status == "running" {
                    Text("暂无统计数据")
                        .foregroundStyle(.secondary)
                } else {
                    Text("容器未运行")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

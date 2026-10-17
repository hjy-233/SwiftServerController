//
//  ServerConsoleView.swift
//  SwiftServerController
//
//  Created by hjy_666 on 2026/10/17.
//

import SwiftServerControllerCore
import SwiftUI

struct ServerConsoleView: View {
    let profile: MinecraftServerProfile

    var body: some View {
        ContentUnavailableView(
            "暂无控制台输出",
            systemImage: "terminal",
            description: Text("\(profile.name) 的日志尚未载入。")
        )
    }
}

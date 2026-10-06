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

    var body: some View {
        VStack {
            Text("版本:\(version)")
            Button("Check") {
                do {
                    version = try ContainerClient().version()
                } catch {
                    version = error.localizedDescription
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

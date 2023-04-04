//
//  CS410_Final_ProjectApp.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/20/23.
//

import SwiftUI

@main
struct CS410_Final_ProjectApp: App {
    @StateObject private var app: AppModel = AppModel()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(app: app)
                .onChange(of: scenePhase) { phase in
                switch phase {
                case .background:
                    app.storeDatabases()
                default:
                    break
                }
            }
        }
    }
}

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
//    @StateObject private var app: AppModel = .mockDatabases
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(app: app).environment(\.schemaDatabase, .shared)
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

// MARK: - Give SwiftUI access to the database
//
// Define a new environment key that grants access to an AppDatabase.
//
// The technique is documented at
// <https://developer.apple.com/documentation/swiftui/environmentkey>.
private struct SchemaDatabaseKey: EnvironmentKey {
    static var defaultValue: SchemaDatabase { .empty() }
}

extension EnvironmentValues {
    var schemaDatabase: SchemaDatabase {
        get { self[SchemaDatabaseKey.self] }
        set { self[SchemaDatabaseKey.self] = newValue }
    }
}

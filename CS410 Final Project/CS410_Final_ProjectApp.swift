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
            // TODO: is there a reason to make the database an environment object when SchemaDatabase.shared exists?
            ContentView(app: app)
                .onChange(of: scenePhase) { phase in
                switch phase {
                case .background:
                    // print the database, table, and column tables each time we go in the background
                    print(String(describing: try? SchemaDatabase.shared.allDatabases()))
                    print(String(describing: try? SchemaDatabase.shared.allTables()))
                    print(String(describing: try? SchemaDatabase.shared.allColumns()))
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

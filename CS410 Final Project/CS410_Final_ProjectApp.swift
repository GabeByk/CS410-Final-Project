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
                    // I commented out the printing code rather than deleting it in case you want to use it
//                    // print the database, table, and column tables each time we go in the background for debugging
//                    let dbs = SchemaDatabase.used.allDatabases()
//                    print(String(describing: dbs))
//                    for db in dbs {
//                        let discDB = UserDatabase.discDatabaseFor(databaseID: db.id)
//                        print(String(describing: discDB))
//                        for table in SchemaDatabase.used.tablesFor(databaseID: db.id) {
//                            print("table \(table.id): \(String(describing: discDB.rowsFor(table: table)))")
//                        }
//                    }
//                    print(String(describing: SchemaDatabase.used.allTables()))
//                    print(String(describing: SchemaDatabase.used.allColumns()))
                    break
                default:
                    break
                }
            }
        }
    }
}

//
//  AppModel.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections

enum NavigationPathCase: Equatable, Hashable {
    case database(EditDatabaseModel)
    case table(EditDatabaseTableModel)
    case column(EditColumnModel)
    case row(EditRowModel)
}

@MainActor
class AppModel: ObservableObject {
    @Published var databases: IdentifiedArrayOf<Database>
    @Published var navigationPath: [NavigationPathCase]
    
    init(databases: IdentifiedArrayOf<Database>? = nil, navigationPath: [NavigationPathCase] = []) {
        if let databases {
            self.databases = databases
        }
        else {
            self.databases = SchemaDatabase.used.allDatabases()
        }
        
        self.navigationPath = navigationPath
    }
}

extension AppModel {
    static var mockDatabases: AppModel {
        let dbs: IdentifiedArrayOf<Database> = [.mockDatabase]
        let app = AppModel(databases: dbs)
        return app
    }
    
    static var mockDatabase: AppModel {
        let db: Database = .mockDatabase
        let app = AppModel(databases: [db])
        app.navigationPath = [.database(EditDatabaseModel(parentModel: EditDatabasesModel(parentModel: app), database: db))]
        return app
    }
    
    static var mockTable: AppModel {
        let app: AppModel = .mockDatabase
        switch app.navigationPath[0] {
        case let .database(model):
            app.navigationPath.append(.table(EditDatabaseTableModel(parentModel: model, table: model.tables[0])))
        default:
            break
        }
        return app
    }
}

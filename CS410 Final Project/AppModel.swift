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
    case entity(EditEntityModel)
    case property(EditPropertyModel)
}

@MainActor
class AppModel: ObservableObject {
    static let schemaFilename = "databases.json"
    @Published var databases: IdentifiedArrayOf<Database>
    @Published var navigationPath: [NavigationPathCase]
    
    init(databases: IdentifiedArrayOf<Database>? = nil, navigationPath: [NavigationPathCase] = []) {
        if let databases {
            self.databases = databases
        }
        else {
            self.databases = loadDatabases()
        }
        
        self.navigationPath = navigationPath
    }
    
    func storeDatabases() {
        let fm = FileManager()
        if let url = fm.urls(for: .documentDirectory, in: .userDomainMask).last {
            let dataURL = url.appendingPathComponent(AppModel.schemaFilename)
            let coder = JSONEncoder()
            if let data = try? coder.encode(databases) {
                do {
                    try data.write(to: dataURL)
                } catch {
                    print("error saving")
                }
            }
        }
    }
}

func loadDatabases() -> IdentifiedArrayOf<Database> {
    let fm = FileManager()
    if let url = fm.urls(for: .documentDirectory, in: .userDomainMask).last {
        let dataURL = url.appendingPathComponent(AppModel.schemaFilename)
        if let data = try? Data(contentsOf: dataURL) {
            let decoder = JSONDecoder()
            if let databases = try? decoder.decode([Database].self, from: data) {
                return IdentifiedArrayOf(uniqueElements: databases)
            }
        }
    }
    // return empty array if failed to load (will automatically convert literal to an IdentifiedArrayOf)
    return []
}

extension AppModel {
    static var mockDatabase: AppModel {
        let db: Database = .mockDatabase
        let app = AppModel(databases: [db])
        app.navigationPath = [.database(EditDatabaseModel(parentModel: EditDatabasesModel(parentModel: app), database: db))]
        return app
    }
    
    static var mockEntity: AppModel {
        let app: AppModel = .mockDatabase
        switch app.navigationPath[0] {
        case let .database(model):
            app.navigationPath.append(.entity(EditEntityModel(parentModel: model, entity: model.entities[0])))
        default:
            break
        }
        return app
    }
}

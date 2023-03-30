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
    @Published var databases: IdentifiedArrayOf<Database>
    @Published var navigationPath: [NavigationPathCase]
    
    init(databases: IdentifiedArrayOf<Database> = [], navigationPath: [NavigationPathCase] = []) {
        self.databases = databases
        self.navigationPath = navigationPath
    }
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

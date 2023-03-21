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
    case property(Property)
}

@MainActor
class AppModel: ObservableObject, DatabasesSaver {
    @Published var databases: IdentifiedArrayOf<Database>
    @Published var navigationPath: [NavigationPathCase]
    
    init(databases: IdentifiedArrayOf<Database> = [], navigationPath: [NavigationPathCase] = []) {
        self.databases = databases
        self.navigationPath = navigationPath
    }
    
    func updateDatabases(databases: IdentifiedArrayOf<Database>) {
        self.databases = databases
    }
}

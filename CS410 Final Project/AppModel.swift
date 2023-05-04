//
//  AppModel.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections

// TODO: cases for columns and rows?
enum NavigationPathCase: Equatable, Hashable {
    case database(EditDatabaseModel)
    case table(EditTableModel)
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

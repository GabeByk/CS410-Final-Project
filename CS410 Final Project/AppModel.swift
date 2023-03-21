//
//  AppModel.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections

@MainActor
class AppModel: ObservableObject, DatabasesSaver {
    @Published var databases: IdentifiedArrayOf<Database>
    
    init(databases: IdentifiedArrayOf<Database> = []) {
        self.databases = databases
    }
    
    func updateDatabases(databases: IdentifiedArrayOf<Database>) {
        self.databases = databases
    }
}

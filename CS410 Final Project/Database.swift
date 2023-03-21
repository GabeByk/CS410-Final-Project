//
//  Table.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import Tagged

struct Database: Identifiable {
    let id: Tagged<Self, UUID>
    var name: String
    var entities: [Entity] = []
    
    init(name: String, id: Tagged<Self, UUID>? = nil) {
        self.name = name
        if let id {
            self.id = id
        }
        else {
            self.id = Database.ID(UUID())
        }
    }
}

extension Database: Equatable, Hashable {
    nonisolated static func == (lhs: Database, rhs: Database) -> Bool {
        return lhs.name == rhs.name && lhs.entities == rhs.entities
    }
}

struct Entity: Identifiable {
    let id: Tagged<Self, UUID>
}

extension Entity: Equatable, Hashable {
}


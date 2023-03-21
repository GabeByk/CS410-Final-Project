//
//  DataModels.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections
import Tagged

struct Database: Identifiable {
    let id: Tagged<Self, UUID>
    var name: String
    var entities: IdentifiedArrayOf<Entity> = []
    
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

struct Entity: Identifiable, Equatable, Hashable {
    // while the primary key should identify it, we want our own in case the user wants to change the primary key later
    let id: Tagged<Self, UUID>
    
    // found sets from https://developer.apple.com/documentation/swift/set
    // set of properties that are unique per entity; each id in the set should be a property in the entity's properties
    var primaryKey: Set<Property.ID>
    var properties: IdentifiedArrayOf<Property> = []
}

struct Property: Identifiable, Equatable, Hashable {
    let id: Tagged<Self, UUID>
    var value: Value?
    
    enum Value: Equatable, Hashable {
        case int(Int)
        case string(String)
        case bool(Bool)
        case double(Double)
        case entity(Entity)
        case array([Value])
    }
}


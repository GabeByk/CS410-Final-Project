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
            self.id = Self.ID(UUID())
        }
    }
}

extension Database {
    static var empty: Database {
        return Database(name: "")
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
    
    var name: String
    
    // found sets from https://developer.apple.com/documentation/swift/set
    var properties: IdentifiedArrayOf<Property> = []
    
    init(name: String, id: Tagged<Self, UUID>? = nil) {
        self.name = name
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
    }
    
    // set of properties that are unique per entity; each id in the set should be a property in the entity's properties
    // could probably be a computed property but it's theta(n) for n properties, so it's a function
    func primaryKey() -> [Property] {
        var key: [Property] = []
        for property in properties {
            if property.isPrimary {
                key.append(property)
            }
        }
        return key
    }
    
    func hasValidPrimaryKey() -> Bool {
        return primaryKey().count > 0
    }

}

extension Entity {
    static var empty: Entity {
        return Entity(name: "")
    }
}

struct Property: Identifiable, Equatable, Hashable {
    let id: Tagged<Self, UUID>
    var isPrimary: Bool
    var name: String
    var value: Value?
    
    init(name: String, value: Value? = nil, isPrimary: Bool = false, id: Tagged<Self, UUID>? = nil) {
        self.name = name
        self.value = value
        self.isPrimary = isPrimary
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
    }
    
    enum Value: Equatable, Hashable {
        case int(Int)
        case string(String)
        case bool(Bool)
        case double(Double)
        case entity(Entity)
    }
}

extension Property {
    static var empty: Property {
        return Property(name: "")
    }
}

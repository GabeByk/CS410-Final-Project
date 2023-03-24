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
//        return lhs.name == rhs.name && lhs.entities == rhs.entities
        return lhs.id == rhs.id
    }
}

struct Entity: Identifiable, Equatable, Hashable {
    // while the primary key should identify it, we want our own in case the user wants to change the primary key later
    let id: Tagged<Self, UUID>
    
    enum PrimaryKey: Equatable, Hashable {
        case id(Entity.ID)
        case property(Property)
        case properties([Property])
    }
    
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
    
    // could probably be a computed property but it's theta(n) for n properties, so it's a function
    ///
    /// Determines which PrimaryKey case is appropriate for this entity, and returns it.
    /// - Returns: PrimaryKey.id(self.id) if no properties are primary, PrimaryKey.property with the member of self.properties marked primary if only one is found,
    /// or PrimaryKey.properties with all properties marked primary if more than one is found.
    func primaryKey() -> PrimaryKey {
        var key: [Property] = []
        for property in properties {
            if property.isPrimary {
                key.append(property)
            }
        }
        if key.count == 0 {
            return .id(id)
        }
        else if key.count == 1 {
            return .property(key[0])
        }
        else {
            return .properties(key)
        }
    }
}

extension Entity {
    static var empty: Entity {
        return Entity(name: "")
    }
}

struct Property: Identifiable, Equatable, Hashable {
    let id: Tagged<Self, UUID>
    /// whether this property is part of the primary key for its entity. a property should be marked as primary if the value of all primary properties for an entity are enough to uniquely determine which instance has those properties.
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
        case entity(Entity.ID)
    }
}

extension Property {
    static var empty: Property {
        return Property(name: "")
    }
}

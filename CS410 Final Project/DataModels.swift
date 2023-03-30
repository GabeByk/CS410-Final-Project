//
//  DataModels.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections
import Tagged
import SwiftUI

struct Database: Identifiable {
    let id: Tagged<Self, UUID>
    var name: String
    var entities: IdentifiedArrayOf<EntityType>
    
    init(name: String, id: Tagged<Self, UUID>? = nil, entities: IdentifiedArrayOf<EntityType> = []) {
        self.name = name
        self.entities = entities
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
    
    static var mockDatabase: Database {
        return Database(name: "Database A", entities: [.mockEntityType])
    }
}

extension Database: Equatable, Hashable, Codable {
    nonisolated static func == (lhs: Database, rhs: Database) -> Bool {
//        return lhs.name == rhs.name && lhs.entities == rhs.entities
        return lhs.id == rhs.id
    }
}

// TODO: ?Should EntityType be a value type?
struct EntityType: Identifiable, Equatable, Hashable, Codable {
    // while the primary key should identify it, we want our own in case the user wants to change the primary key later
    let id: Tagged<Self, UUID>
    
    enum PrimaryKey: Equatable, Hashable {
        case id(EntityType.ID)
        case property(PropertyType)
        case properties([PropertyType])
    }
    
    var name: String
    var instances: IdentifiedArrayOf<Entity>
    var shouldShow: Bool
    
    // found sets from https://developer.apple.com/documentation/swift/set
    var properties: IdentifiedArrayOf<PropertyType>
    
    init(name: String, shouldShow: Bool = true, id: Tagged<Self, UUID>? = nil, properties: IdentifiedArrayOf<PropertyType> = [], instances: IdentifiedArrayOf<Entity> = []) {
        self.name = name
        self.shouldShow = shouldShow
        self.instances = instances
        self.properties = properties
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
    }
    
    mutating func removeProperty(_ property: PropertyType) {
        properties.remove(property)
        for var instance in instances {
            instance.removeValueFor(property: property)
        }
    }
    
    mutating func removeProperties(at offsets: IndexSet) {
        for index in offsets {
            let property = properties[index]
            for var instance in instances {
                instance.removeValueFor(property: property)
            }
        }
        properties.remove(atOffsets: offsets)
    }
    
    mutating func addProperty(_ property: PropertyType) {
        properties[id: property.id] = property
        for var instance in instances {
            instance.updateValueFor(property: property, newValue: property.type)
        }
    }
    
    mutating func addInstance() {
        instances.append(Entity())
    }
    
    // could probably be a computed property but it's theta(n) for n properties, so it's a function
    ///
    /// Determines which PrimaryKey case is appropriate for this entity, and returns it.
    /// - Returns: PrimaryKey.id(self.id) if no properties are primary, PrimaryKey.property with the member of self.properties marked primary if only one is found,
    /// or PrimaryKey.properties with all properties marked primary if more than one is found.
    func primaryKey() -> PrimaryKey {
        var key: [PropertyType] = []
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

extension EntityType {
    static var empty: EntityType {
        return EntityType(name: "")
    }
    
    static var mockEntityType: EntityType {
        return EntityType(name: "Entity A", properties: [.mockPropertyType])
    }
    
    static func shouldShowImage(shouldShow: Bool) -> Image {
        Image(systemName: shouldShow ? "key.fill" : "key")
    }
}

// TODO: ?now that Value is its own thing, should PropertyType be a value type?
struct PropertyType: Identifiable, Equatable, Hashable, Codable {
    let id: Tagged<Self, UUID>
    /// whether this property is part of the primary key for its entity. a property should be marked as primary if the value of all primary properties for an entity are enough to uniquely determine which instance has those properties.
    var isPrimary: Bool
    var name: String
    var type: Value
    
    init(name: String, type: Value, isPrimary: Bool = false, id: Tagged<Self, UUID>? = nil) {
        self.name = name
        self.type = type
        self.isPrimary = isPrimary
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
    }
}

extension PropertyType {
    var valueType: String {
        switch type {
        case .int:
            return Value.stringForInt
        case .string:
            return Value.stringForString
        case .bool:
            return Value.stringForBool
        case .double:
            return Value.stringForDouble
        case .entity(_):
            return Value.stringForEntity
        }
    }
    
    static var empty: PropertyType {
        return PropertyType(name: "", type: .string(nil))
    }
    
    static var mockPropertyType: PropertyType {
        return PropertyType(name: "Property A", type: .string(nil))
    }
    
    static func primaryKeyImage(isPrimary: Bool) -> Image {
        Image(systemName: isPrimary ? "key.fill" : "key")
    }
}

enum Value: Equatable, Hashable, Codable {
    case int(Int?)
    case string(String?)
    case bool(Bool?)
    case double(Double?)
    case entity(EntityType.ID?)
}

extension Value {
    // might make sense for these to be immutable stored properties rather than compted properties
    static var stringForInt: String {
        "Integer"
    }
    static var stringForString: String {
        "Text"
    }
    static var stringForBool: String {
        "True or False"
    }
    static var stringForDouble: String {
        "Decimal"
    }
    static var stringForEntity: String {
        "Entity"
    }
}

struct Entity: Identifiable, Equatable, Hashable, Codable {
    // TODO: ?should each entity have a weak link to its EntityType? or just its EntityType's ID?
    // if weak link, then EntityType should for sure be a reference type
    let id: Tagged<Self, UUID>
    // https://developer.apple.com/documentation/swift/dictionary
    
    // TODO: ?different data structure so we guarantee we have a value if and only if our EntityType has a property for that value?
    var values: Dictionary<PropertyType.ID, Value>
    
    init(values: Dictionary<PropertyType.ID, Value> = [:], id: Tagged<Self, UUID>? = nil) {
        if values.count != 0 {
            self.values = values
        }
        else {
            // TODO: initialize values to have nil for each PropertyType that the parent entity has. might require knowledge of EntityType
            self.values = [:]
        }
        
        if let id {
            self.id = id
        } else {
            self.id = Self.ID(UUID())
        }
    }
    
    // TODO: ?should the API have you pass the property type or just its id?
    func valueFor(property: PropertyType) -> Value? {
        return values[property.id]
    }
    
    mutating func updateValueFor(property: PropertyType, newValue: Value) {
        values[property.id] = newValue
    }
    
    mutating func removeValueFor(property: PropertyType) {
        // the documentation says assigning a dictionary entry to nil removes it from the dictionary, which is handy
        values[property.id] = nil
    }
}

extension Entity {
    static var empty: Entity {
        return Entity()
    }
}

extension Entity: CustomStringConvertible {
    var description: String {
        return String(describing: id)
    }
}

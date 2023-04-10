//
//  DataModels.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections
// used for the EntityType and PropertyType's static properties for their images
import SwiftUI
import GRDB

// TODO: can GRDB deal with Tagged<Self, Int64> as ID's data type and/or is that a good idea?

struct Database: Identifiable {
    public private(set) var id: Int64?
    var name: String
    // TODO: use GRDB to store and access entities
    var entities: IdentifiedArrayOf<EntityType>
    
    init(name: String, id: Int64? = nil, entities: IdentifiedArrayOf<EntityType> = []) {
        self.name = name
        self.entities = entities
        self.id = id
    }
    
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
        }
    }
}

extension Database {
    static var empty: Database {
        return Database(name: "")
    }
    
    static var mockDatabase: Database {
        return Database(name: "Database A", id: -1, entities: [.mockEntityType])
    }
}

extension Database: Equatable, Hashable {
    nonisolated static func == (lhs: Database, rhs: Database) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - EntityType

struct EntityType: Identifiable, Equatable, Hashable{
    // while the primary key should identify it, we want our own ID in case the user wants to change the primary key later
    public private(set) var id: Int64?
    // which database this belongs to
    var databaseID: Int64
    
    enum PrimaryKey: Equatable, Hashable {
        case id(EntityType.ID)
        case property(PropertyType)
        case properties([PropertyType])
    }
    
    var name: String
    // TODO: don't encode and decode instances in AppModel.schemaFilename, since that info will go in the database using GRDB.
    // TODO: use GRDB to access entities
    var entities: IdentifiedArrayOf<Entity>
    // TODO?: is this functionality necessary? having to show helper tables to work on them and add data will be kind of annoying
    var shouldShow: Bool
    
    // TODO: use GRDB to access properties
    var properties: IdentifiedArrayOf<PropertyType>
    
    init(name: String, shouldShow: Bool = true, id: Int64? = nil, properties: IdentifiedArrayOf<PropertyType> = [], entities: IdentifiedArrayOf<Entity> = [], databaseID: Int64) {
        self.name = name
        self.shouldShow = shouldShow
        self.entities = entities
        self.properties = properties
        self.id = id
        self.databaseID = databaseID
    }
    
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
        }
    }
    
    mutating func removeProperty(_ property: PropertyType) {
        properties.remove(property)
        for var instance in entities {
            #warning("force unwrapping a PropertyType's ID in EntityType.removeProperty")
            instance.removeValueFor(propertyTypeID: property.id!)
        }
    }
    
    mutating func removeProperties(at offsets: IndexSet) {
        for index in offsets {
            let property = properties[index]
            removeProperty(property)
        }
    }
    
    mutating func addProperty(_ property: PropertyType) {
        properties[id: property.id] = property
        let value: Value
        switch property.type {
        case .int:
            value = .int(nil)
        case .string:
            value = .string(nil)
        case .bool:
            value = .bool(nil)
        case .double:
            value = .double(nil)
        // TODO: does the Value enum need to have the EntityType for the GUI to be able to scroll through all entities of that type?
        // it should know which property type it is, and the property type knows which entity type it has, so it shouldn't be necessary
        case .entity(_):
            value = .entity(nil)
        }
        for var instance in entities {
            #warning("force unwrapping PropertyType.ID in EntityType.addProperty")
            instance.updateValueFor(propertyTypeID: property.id!, newValue: value)
        }
    }
    
    mutating func addInstance() {
        #warning("defaulting entityTypeID to -2 in EntityType.addInstance")
        entities.append(.empty(entityTypeID: id ?? -2))
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
    static func empty(databaseID: Int64) -> EntityType {
        return EntityType(name: "", databaseID: databaseID)
    }
    
    static var mockEntityType: EntityType {
        return EntityType(name: "Entity A", id: -1, properties: [.mockPropertyType], databaseID: Database.mockDatabase.id ?? 0)
    }
    
    static func shouldShowImage(shouldShow: Bool) -> Image {
        Image(systemName: shouldShow ? "key.fill" : "key")
    }
}

// MARK: - PropertyType

struct PropertyType: Identifiable, Equatable, Hashable {
    public private(set) var id: Int64?
    /// whether this property is part of the primary key for its entity. a property should be marked as primary if the value of all primary properties for an entity are enough to uniquely determine which instance has those properties.
    var isPrimary: Bool
    var name: String
    var type: ValueType
    // which EntityType this property is for
    var entityTypeID: Int64
    
    init(name: String, type: ValueType, isPrimary: Bool = false, id: Int64? = nil, entityTypeID: Int64) {
        self.name = name
        self.type = type
        self.isPrimary = isPrimary
        self.id = id
        self.entityTypeID = entityTypeID
    }
    
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
        }
    }
}

extension PropertyType {
    var valueType: String {
        switch type {
        case .int:
            return ValueType.stringForInt
        case .string:
            return ValueType.stringForString
        case .bool:
            return ValueType.stringForBool
        case .double:
            return ValueType.stringForDouble
        case .entity(_):
            return ValueType.stringForEntity
        }
    }
    
    static func empty(entityTypeID: Int64) -> PropertyType {
        return PropertyType(name: "", type: .string, entityTypeID: entityTypeID)
    }
    
    static var mockPropertyType: PropertyType {
        return PropertyType(name: "Property A", type: .string, id: -1, entityTypeID: EntityType.mockEntityType.id ?? 0)
    }
    
    static func primaryKeyImage(isPrimary: Bool) -> Image {
        Image(systemName: isPrimary ? "key.fill" : "key")
    }
}

// MARK: - ValueType

enum ValueType: Equatable, Hashable, Codable {
    case int
    case string
    case bool
    case double
    case entity(EntityType.ID?)
}

extension ValueType {
    static let stringForInt = "Integer"
    static let stringForString = "Text"
    static let stringForBool = "True or False"
    static let stringForDouble = "Decimal"
    static let stringForEntity = "Entity"
}

// MARK: - Value

enum Value: Equatable, Hashable, Codable {
    case int(Int?)
    case string(String?)
    case bool(Bool?)
    case double(Double?)
    case entity(Entity.ID?)
}

// MARK: - Entity

struct Entity: Identifiable, Equatable, Hashable {
    public private(set) var id: Int64?
    // which EntityType this is an instance of
    var entityTypeID: Int64
    // https://developer.apple.com/documentation/swift/dictionary
    // TODO: use GRDB to access Properties by PropertyType ID (if possible?)
    var properties: Dictionary<Int64, Property>
    
    init(propertyTypes: IdentifiedArrayOf<PropertyType>? = nil, id: Int64? = nil, entityTypeID: Int64) {
        self.id = id
        self.properties = [:]
        if let propertyTypes {
            for propertyType in propertyTypes {
                // figure out which kind of value we should have
                let value: Value
                switch propertyType.type {
                case .int:
                    value = .int(nil)
                case .string:
                    value = .string(nil)
                case .bool:
                    value = .bool(nil)
                case .double:
                    value = .double(nil)
                case .entity(_):
                    value = .entity(nil)
                }
                
                #warning("defaulting entityID to -2 in Entity.init")
                let property = Property(entityID: id ?? -2, value: value)
                self.properties[propertyType.id ?? -2] = property
            }
        }
        self.entityTypeID = entityTypeID
    }
    
    func valueFor(propertyTypeID: Int64) -> Value? {
        return properties[propertyTypeID]?.value
    }
    
    ///
    /// if the ID has not already been set, set it to the given ID.
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
        }
    }
    
    ///
    /// if the entity has this property, it will update its value. otherwise, it will add this property to its properties and give it the given value
    mutating func updateValueFor(propertyTypeID: Int64, newValue: Value) {
        if properties[propertyTypeID] != nil {
            properties[propertyTypeID]!.value = newValue
        }
        else {
            properties[propertyTypeID] = Property(entityID: id ?? -2, value: newValue)
        }
    }
    
    mutating func removeValueFor(propertyTypeID: Int64) {
        // assigning a dictionary's value for a given type sets it to nil
        properties[propertyTypeID] = nil
    }
}

extension Entity {
    // TODO: empty as an instance method of the parent class instead? or even the addEntity makes its own instead of using this
    static func empty(entityTypeID: Int64) -> Entity {
        return Entity(entityTypeID: entityTypeID)
    }
}

extension Entity: CustomStringConvertible {
    var description: String {
        return String(describing: id)
    }
}

// MARK: - Property
struct Property: Identifiable, Equatable, Hashable {
    public private(set) var id: Int64?
    // which entity this property is for
    var entityID: Int64
    // TODO: we might need to have a propertyTypeID so GRDB can find us by PropertyTypeID
    var value: Value

    /// if the ID has not already been set, set it to the given ID.
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
        }
    }
}

// MARK: - GRDB setup

extension Database: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let entities = hasMany(EntityType.self, using: EntityType.databaseForeignKey)
    enum Columns {
        static let name = Column(CodingKeys.name)
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension EntityType: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let databaseForeignKey = ForeignKey(["databaseID"])
    static let database = belongsTo(Database.self, using: databaseForeignKey)
    
    static let properties = hasMany(PropertyType.self, using: PropertyType.entityTypeForeignKey)
    static let entities = hasMany(Entity.self, using: Entity.entityTypeForeignKey)
    
    enum Columns {
        static let name = Column(CodingKeys.name)
        static let shouldShow = Column(CodingKeys.shouldShow)
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension PropertyType: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let entityTypeForeignKey = ForeignKey(["entityTypeID"])
    static let entityType = belongsTo(EntityType.self, using: entityTypeForeignKey)
    
    enum Columns {
        static let name = Column(CodingKeys.name)
        static let isPrimary = Column(CodingKeys.isPrimary)
        static let type = Column(CodingKeys.type)
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Entity: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let entityTypeForeignKey = ForeignKey(["entityTypeID"])
    static let entityType = belongsTo(EntityType.self, using: entityTypeForeignKey)
    
    // TODO: does this need to have a different using to look up by PropertyType ID?
    static let properties = hasMany(Property.self, using: Property.entityForeignKey)
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Property: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let entityForeignKey = ForeignKey(["entityID"])
    static let entity = belongsTo(Entity.self, using: entityForeignKey)
    
    enum Columns {
        static let value = Column(CodingKeys.value)
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

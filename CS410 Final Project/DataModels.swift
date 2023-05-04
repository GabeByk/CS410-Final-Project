//
//  DataModels.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections
import Tagged
import GRDB
// used for the DatabaseTable and DatabaseColumn's static properties for their images
import SwiftUI

struct Database: Identifiable {
    var id: Tagged<Self, UUID>
    
    var name: String
    
    init(name: String, id: Database.ID? = nil) {
        self.name = name
        if let id {
            self.id = id
        }
        else {
            self.id = Database.ID(UUID())
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
        return lhs.id == rhs.id
    }
}

// MARK: - DatabaseTable

struct DatabaseTable: Identifiable, Equatable, Hashable{
    // while the primary key should identify it, we want our own ID in case the user wants to change the primary key later
    var id: Tagged<Self, UUID>
    
    // which database this table belongs to
    var databaseID: Database.ID
    
    var name: String
    
    // the possible cases the primary key could be
    enum PrimaryKey: Equatable, Hashable {
        // if no columns are primary; the UUID of the table is the associated value
        case id(DatabaseTable.ID)
        // if exactly one column is used; which column it is is the associated value
        case column(DatabaseColumn)
        // if more than one column is used; which columns are used is the associated value
        case columns([DatabaseColumn])
    }
    
    var shouldShow: Bool
    
    init(name: String, shouldShow: Bool = true, id: Self.ID? = nil, columns: IdentifiedArrayOf<DatabaseColumn> = [], rows: IdentifiedArrayOf<DatabaseRow> = [], databaseID: Database.ID) {
        self.name = name
        self.shouldShow = shouldShow
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
        self.databaseID = databaseID
    }
    
    // could probably be a computed property but it's theta(n) for n columns, so it's a function
    /// Determines which PrimaryKey case is appropriate for this table, and returns it.
    /// - Returns: PrimaryKey.id(self.id) if no columns are primary, PrimaryKey.column with the member of self.columns marked primary if only one is found,
    /// or PrimaryKey.columns with all columns marked primary if more than one is found.
    func primaryKey() -> PrimaryKey {
        var key: [DatabaseColumn] = []
        for column in SchemaDatabase.used.columnsFor(tableID: id) {
            if column.isPrimary {
                key.append(column)
            }
        }
        if key.count == 0 {
            return .id(id)
        }
        else if key.count == 1 {
            return .column(key[0])
        }
        else {
            return .columns(key)
        }
    }
}

extension DatabaseTable {
    static func empty(databaseID: Database.ID) -> DatabaseTable {
        return DatabaseTable(name: "", databaseID: databaseID)
    }
    
    var shouldShowImage: Image {
        Image(systemName: shouldShow ? "eye.fill" : "eye.slash")
    }
}

// MARK: - ValueType

enum ValueType: String, Equatable, Hashable, Codable, DatabaseValueConvertible {
    case int = "Integer"
    case string = "Text"
    case bool = "True or False"
    case double = "Decimal"
    case table = "Table"
}

// MARK: - StoredValue

enum StoredValue: Equatable, Hashable, Codable {
    case int(Int?)
    case string(String?)
    case bool(Bool?)
    case double(Double?)
    case row(referencedRowID: DatabaseRow.ID?, referencedTableID: DatabaseTable.ID?)
}

extension StoredValue: CustomStringConvertible {
    var description: String {
        descriptionsHelper(recursive: true)
    }
    
    var nonRecursiveDescription: String {
        descriptionsHelper(recursive: false)
    }
    
    private func descriptionsHelper(recursive: Bool) -> String {
        switch self {
        // for everything but a row, return the NULL if it's nil or the literal string version if it isn't
        case let .int(i):
            return i == nil ? "NULL" : String(i!)
        case let .string(s):
            return s ?? "NULL"
        case let .bool(b):
            // we want booleans to be capitalized for in-app display, so we convert to a string ourselves
            return b == nil ? "NULL" : (b! ? "True" : "False")
        case let .double(d):
            return d == nil ? "NULL" : String(d!)
        // for a row, we might want its description, or just its UUID
        case let .row(referencedRowID, referencedTableID):
            if let referencedRowID, let referencedTableID {
                if recursive {
                    // look up its description, if we can
                    if let table = SchemaDatabase.used.table(id: referencedTableID) {
                        let database = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
                        let row = database.row(rowID: referencedRowID, tableID: referencedTableID)
                        // if we use the row's recursive description, we could get in an infinite recursive loop, so use the non-recursive description even though recursive is true
                        // the ideal functionality would have it go to the bottom if there is one, or cut it off early if there isn't, but I can't think of a good way to do that without keeping track of which rows we've asked for the description of as an extra parameter or something
                        return "Holds: \(row?.nonRecursiveDescription ?? "NULL")"
                    }
                }
                // if recursive is false or the lookup failed, we return the UUID
                return "Holds UUID: \(referencedRowID.uuidString)"
            }
            // if the row ID or table ID is nil, return NULL
            else {
                return "NULL"
            }
        }
    }
}

// MARK: - DatabaseColumn

struct DatabaseColumn: Identifiable, Equatable, Hashable {
    var id: Tagged<Self, UUID>
    // whether this column is part of the primary key for its table
    var isPrimary: Bool
    
    // the title of this column
    var name: String
    
    // which data type this column should hold
    var type: ValueType
    
    // if type is .table, which DatabaseTable this DatabaseColumn holds
    var referencedTableID: DatabaseTable.ID?
    
    // which DatabaseTable holds this column
    var tableID: DatabaseTable.ID
    
    init(name: String, type: ValueType, isPrimary: Bool = false, id: Self.ID? = nil, tableID: DatabaseTable.ID) {
        self.name = name
        self.type = type
        self.isPrimary = isPrimary
        self.tableID = tableID
        
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
    }
}

extension DatabaseColumn {
    var valueType: String {
        switch type {
        case .table:
            if let referencedTableID {
                if let referencedTable = SchemaDatabase.used.table(id: referencedTableID) {
                    return "\(referencedTable.name)"
                }
                return "Table not found"
            }
            return "Table not selected"
        default:
            return type.rawValue
        }
    }
    
    static func empty(tableID: DatabaseTable.ID) -> DatabaseColumn {
        return DatabaseColumn(name: "", type: .string, tableID: tableID)
    }
    
    var primaryKeyImage: Image {
        Image(systemName: isPrimary ? "key.fill" : "key")
    }
}


// MARK: - DatabaseRow

struct DatabaseRow: Identifiable, Equatable, Hashable {
    static func == (lhs: DatabaseRow, rhs: DatabaseRow) -> Bool {
        return lhs.id == rhs.id
    }
    
    var id: Tagged<Self, UUID>
    // which DatabaseTable this is an instance of
    let tableID: DatabaseTable.ID
    
    // the data stored in the database for this row, keyed by column ID
    private var values: Dictionary<DatabaseColumn.ID, StoredValue>
    
    init(columns: IdentifiedArrayOf<DatabaseColumn>? = nil, id: Self.ID? = nil, tableID: DatabaseTable.ID) {
        self.tableID = tableID
        
        // use the passed ID, if any
        if let id {
            self.id = id
        }
        // otherwise, create our own
        else {
            self.id = Self.ID(UUID())
        }
        
        // initialize self.values
        self.values = [:]
        if let columns {
            for column in columns {
                // setting it to nil removes the entry in the dictionary; we want a StoredValue with associated value nil
                let value: StoredValue
                switch column.type {
                case .table:
                    value = .row(referencedRowID: nil, referencedTableID: column.referencedTableID)
                case .int:
                    value = .int(nil)
                case .string:
                    value = .string(nil)
                case .bool:
                    value = .bool(nil)
                case .double:
                    value = .double(nil)
                }
                self.values[column.id] = value
            }
        }
    }
    
    /// - returns: the value this row has for the given column, if any. returns nil only if the row doesn't have this column.
    func valueFor(columnID: DatabaseColumn.ID) -> StoredValue? {
        return values[columnID]
    }
    
    /// if the row has this column, it will update its value. otherwise, it will add this column to its columns and give it the given value
    mutating func updateValueFor(columnID: DatabaseColumn.ID, newValue: StoredValue) {
        values[columnID] = newValue
    }
}

extension DatabaseRow {
    static func empty(tableID: DatabaseTable.ID) -> DatabaseRow {
        return DatabaseRow(tableID: tableID)
    }
}

extension DatabaseRow: CustomStringConvertible {
    var description: String {
        return descriptionsHelper(recursive: true)
    }
    
    var nonRecursiveDescription: String {
        return descriptionsHelper(recursive: false)
    }
    
    private func descriptionsHelper(recursive: Bool) -> String {
        // fetch the table this row belongs to so we can know its primary key
        if let table = SchemaDatabase.used.table(id: tableID) {
            // use the primary key to determine what information is output
            let primaryKey = table.primaryKey()
            switch primaryKey {
            // if the primary key is our UUID, show that
            case .id(_):
                return "UUID: " + id.uuidString
            // if it's a single column, show the description of our value for it
            case let .column(column):
                if let value = valueFor(columnID: column.id) {
                    return recursive ? value.description : value.nonRecursiveDescription
                }
                else {
                    return "NULL"
                }
            // if it's a group of columns, show them in parentheses with labels (e.g. (Name: Club, Cost: 1 sp))
            case let .columns(columns):
                var keyValues: String = "("
                for column in columns {
                    // add the column label
                    keyValues += "\(column.name): "
                    
                    // add the stored value for the column
                    if let value = valueFor(columnID: column.id) {
                        keyValues += recursive ? value.description : value.nonRecursiveDescription
                    }
                    else {
                        keyValues += "NULL"
                    }
                    
                    // separate with a comma or add the closing )
                    if column != columns.last {
                        keyValues += ", "
                    }
                    else {
                        keyValues += ")"
                    }
                }
                return keyValues
            }
        }
        // if we can't find the table, use the UUID as the ID
        else {
            return "UUID: " + id.uuidString
        }
    }
}

// MARK: - GRDB setup

extension Database: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let tables = hasMany(DatabaseTable.self, using: DatabaseTable.databaseForeignKey)
    enum Columns {
        static let name = Column(CodingKeys.name)
    }
}

extension DatabaseTable: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let databaseForeignKey = ForeignKey(["databaseID"])
    static let database = belongsTo(Database.self, using: databaseForeignKey)
    
    static let columns = hasMany(DatabaseColumn.self, using: DatabaseColumn.tableForeignKey)
    
    enum Columns {
        static let name = Column(CodingKeys.name)
        static let shouldShow = Column(CodingKeys.shouldShow)
    }
}

extension DatabaseColumn: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let tableForeignKey = ForeignKey(["tableID"])
    static let table = belongsTo(DatabaseTable.self, using: tableForeignKey)
    
    static let referencedTableForeignKey = ForeignKey(["referencedTableID"])
    static let referencedTable = hasOne(DatabaseTable.self, using: referencedTableForeignKey)
    
    enum Columns {
        static let name = Column(CodingKeys.name)
        static let isPrimary = Column(CodingKeys.isPrimary)
        static let type = Column(CodingKeys.type)
    }
}

extension DatabaseRow: Codable, FetchableRecord {
    // we need custom codable conformance because values isn't stored in the database as a dictionary
    enum CodingKeys: String, CodingKey {
        case id
        case tableID
    }
    
    init(from decoder: Decoder) throws {
        // extract our ID and our table's ID normally, since we'll need them later
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(DatabaseRow.ID.self, forKey: .id)
        tableID = try container.decode(DatabaseTable.ID.self, forKey: .tableID)
        
        // the code for extracting self.values from the database is written in UserDatabase.row and doesn't rely on this function, so use it here
        if let table = SchemaDatabase.used.table(id: tableID) {
            let database = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
            self.values = database.row(rowID: id, tableID: tableID)?.values ?? [:]
        }
        // if looking up the table failed, just initialize values to be empty
        else {
            values = [:]
        }
    }
}

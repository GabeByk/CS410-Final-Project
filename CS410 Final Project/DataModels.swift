//
//  DataModels.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections
import Tagged
// used for the DatabaseTable and DatabaseColumn's static properties for their images
import SwiftUI
import GRDB

struct Database: Identifiable {
    public private(set) var id: Tagged<Self, UUID>
    var name: String
    var tables: IdentifiedArrayOf<DatabaseTable> {
        return SchemaDatabase.used.tablesFor(databaseID: id)
    }
    
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
    static let mockID: Self.ID = Self.ID(UUID())
    
    static var empty: Database {
        return Database(name: "")
    }
    
    static var mockDatabase: Database {
        return Database(name: "Database A", id: Database.mockID)
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
    public private(set) var id: Tagged<Self, UUID>
    // which database this belongs to
    var databaseID: Database.ID
    
    enum PrimaryKey: Equatable, Hashable {
        case id(DatabaseTable.ID)
        case column(DatabaseColumn)
        case columns([DatabaseColumn])
    }
    
    var name: String
    
    var rows: IdentifiedArrayOf<DatabaseRow> {
        return DataDatabase.discDatabaseFor(databaseID: databaseID).rowsFor(table: self)
    }
    
    var columns: IdentifiedArrayOf<DatabaseColumn> {
        return SchemaDatabase.used.columnsFor(tableID: id)
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
    
    mutating func removeColumn(_ column: DatabaseColumn) {
        for var instance in rows {
            instance.removeValueFor(columnID: column.id)
        }
    }
    
    mutating func removeColumns(at offsets: IndexSet) {
        for index in offsets {
            let column = columns[index]
            removeColumn(column)
        }
    }
    
    mutating func addColumn(_ column: DatabaseColumn) {
        for var instance in rows {
            let newValue: StoredValue
            switch column.type {
            case .int:
                newValue = .int(nil)
            case .string:
                newValue = .string(nil)
            case .bool:
                newValue = .bool(nil)
            case .double:
                newValue = .double(nil)
            case .table:
                newValue = .row(referencedRowID: nil, referencedTableID: column.referencedTableID)
            }
            instance.updateValueFor(columnID: column.id, newValue: newValue)
        }
    }
    
    // could probably be a computed property but it's theta(n) for n columns, so it's a function
    ///
    /// Determines which PrimaryKey case is appropriate for this table, and returns it.
    /// - Returns: PrimaryKey.id(self.id) if no columns are primary, PrimaryKey.column with the member of self.columns marked primary if only one is found,
    /// or PrimaryKey.columns with all columns marked primary if more than one is found.
    func primaryKey() -> PrimaryKey {
        var key: [DatabaseColumn] = []
        for column in columns {
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
    static let mockID = Self.ID(UUID())
    
    static func empty(databaseID: Database.ID) -> DatabaseTable {
        return DatabaseTable(name: "", databaseID: databaseID)
    }
    
    static var mockDatabaseTable: DatabaseTable {
        return DatabaseTable(name: "Table A", id: DatabaseTable.mockID, columns: [.mockColumn], databaseID: Database.mockID)
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

enum StoredValue: Equatable, Hashable, Codable {
    case int(Int?)
    case string(String?)
    case bool(Bool?)
    case double(Double?)
    case row(referencedRowID: DatabaseRow.ID?, referencedTableID: DatabaseTable.ID?)
}

extension StoredValue: CustomStringConvertible {
    var description: String {
        switch self {
        case let .int(i):
            return i == nil ? "NULL" : String(i!)
        case let .string(s):
            return s ?? "NULL"
        case let .bool(b):
            return b == nil ? "NULL" : (b! ? "True" : "False")
        case let .double(d):
            return d == nil ? "NULL" : String(d!)
        case let .row(referencedRowID, referencedTableID):
            if let referencedRowID, let referencedTableID {
                if let table = SchemaDatabase.used.table(id: referencedTableID) {
                    let database = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
                    let row = database.row(rowID: referencedRowID, tableID: referencedTableID)
                    return row?.nonRecursiveDescription ?? "NULL"
                }
                return "Holds UUID: \(referencedRowID.uuidString)"
            }
        }
        return "NULL"
    }
    
    var nonRecursiveDescription: String {
        switch self {
        case let .int(i):
            return i == nil ? "NULL" : String(i!)
        case let .string(s):
            return s ?? "NULL"
        case let .bool(b):
            return b == nil ? "NULL" : (b! ? "True" : "False")
        case let .double(d):
            return d == nil ? "NULL" : String(d!)
        case let .row(referencedRowID, _):
            if let referencedRowID {
                return "Holds UUID: \(referencedRowID.uuidString)"
            }
        }
        return "NULL"
    }
}

// MARK: - DatabaseColumn

struct DatabaseColumn: Identifiable, Equatable, Hashable {
    public private(set) var id: Tagged<Self, UUID>
    // whether this column is part of the primary key for its table. a column should be marked as primary if the value of all primary columns for a table are enough to uniquely determine which row has those values.
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
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
        self.tableID = tableID
    }
}

extension DatabaseColumn {
    static let mockID = Self.ID(UUID())
    
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
    
    static var mockColumn: DatabaseColumn {
        return DatabaseColumn(name: "Column A", type: .string, id: DatabaseColumn.mockID, tableID: DatabaseTable.mockID)
    }
    
    var primaryKeyImage: Image {
        Image(systemName: isPrimary ? "key.fill" : "key")
    }
}


// MARK: - DatabaseRow

struct DatabaseRow: Identifiable, Equatable, Hashable {
    static func == (lhs: DatabaseRow, rhs: DatabaseRow) -> Bool {
        return lhs.id == rhs.id // && lhs.tableID == rhs.tableID && lhs.values == rhs.values // Type 'any StoredByUser' cannot conform to Equatable
    }
    
    public private(set) var id: Tagged<Self, UUID>
    // which DatabaseTable this is an instance of
    let tableID: DatabaseTable.ID
    // https://developer.apple.com/documentation/swift/dictionary
    // TODO?: computed property that looks up data in the database
    var values: Dictionary<DatabaseColumn.ID, StoredValue>
    
    init(columns: IdentifiedArrayOf<DatabaseColumn>? = nil, id: Self.ID? = nil, tableID: DatabaseTable.ID) {
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
        self.values = [:]
        if let columns {
            for column in columns {
                self.values[column.id] = nil
            }
        }
        self.tableID = tableID
    }
    
    func valueFor(columnID: DatabaseColumn.ID) -> StoredValue? {
        return values[columnID]
    }
    
    ///
    /// if the row has this column, it will update its value. otherwise, it will add this column to its columns and give it the given value
    mutating func updateValueFor(columnID: DatabaseColumn.ID, newValue: StoredValue) {
        values[columnID] = newValue
    }
    
    mutating func removeValueFor(columnID: DatabaseColumn.ID) {
        // assigning a dictionary's value for a given type sets it to nil
        values[columnID] = nil
    }
}

extension DatabaseRow {
    static func empty(tableID: DatabaseTable.ID) -> DatabaseRow {
        return DatabaseRow(tableID: tableID)
    }
}

extension DatabaseRow: CustomStringConvertible {
    var description: String {
        if let table = SchemaDatabase.used.table(id: tableID) {
            let primaryKey = table.primaryKey()
            switch primaryKey {
            case .id(_):
                return "Has UUID: " + id.uuidString
            case let .column(column):
                if let value = valueFor(columnID: column.id) {
                    return value.description
                }
                else {
                    return "\(column.name): NULL"
                }
            case let .columns(columns):
                var keyValues: String = "("
                for column in columns {
                    keyValues += (column.name + ": " + (values[column.id]?.description ?? "NULL"))
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
        else {
            return id.uuidString
        }
    }
    
    var nonRecursiveDescription: String {
        if let table = SchemaDatabase.used.table(id: tableID) {
            let primaryKey = table.primaryKey()
            switch primaryKey {
            case .id(_):
                return "Holds UUID: " + id.uuidString
            case let .column(column):
                if let value = valueFor(columnID: column.id) {
                    return value.nonRecursiveDescription
                }
                else {
                    return "\(column.name): NULL"
                }
            case let .columns(columns):
                var keyValues: String = "("
                for column in columns {
                    keyValues += (column.name + ": " + (values[column.id]?.nonRecursiveDescription ?? "NULL"))
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
        else {
            return id.uuidString
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
    enum CodingKeys: String, CodingKey {
        case id
        case tableID
    }
    
    init(from decoder: Decoder) throws {
        // https://www.hackingwithswift.com/articles/119/codable-cheat-sheet
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(DatabaseRow.ID.self, forKey: .id)
        tableID = try container.decode(DatabaseTable.ID.self, forKey: .tableID)
        if let table = SchemaDatabase.used.table(id: tableID) {
            let database = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
            self.values = database.row(rowID: id, tableID: tableID)?.values ?? [:]
        }
        else {
            values = [:]
        }
    }
}

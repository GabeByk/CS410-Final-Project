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
    // TODO: use GRDB to store and access Database.tables
    var tables: IdentifiedArrayOf<DatabaseTable> {
        return (try? SchemaDatabase.shared.tablesFor(databaseID: id)) ?? []
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
    
    // TODO: get rows from the appropriate database based on databaseID
    var rows: IdentifiedArrayOf<DatabaseRow> {
        return []
    }
    
    // TODO: use GRDB to access columns
    var columns: IdentifiedArrayOf<DatabaseColumn> {
        return (try? SchemaDatabase.shared.columnsFor(tableID: id)) ?? []
    }
    
    // TODO?: is this functionality necessary? having to show helper tables to work on them and add data will be kind of annoying
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
            instance.updateValueFor(columnID: column.id, newValue: nil)
        }
    }
    
    mutating func addInstance() {
        // TODO: add a row to the table
//        #warning("defaulting tableID to -2 in DatabaseTable.addInstance")
//        rows.append(.empty(tableID: id ?? -2))
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
    
    static func shouldShowImage(shouldShow: Bool) -> Image {
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
    var associatedTableID: DatabaseTable.ID?
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
        return type.rawValue
    }
    
    static func empty(tableID: DatabaseTable.ID) -> DatabaseColumn {
        return DatabaseColumn(name: "", type: .string, tableID: tableID)
    }
    
    static var mockColumn: DatabaseColumn {
        return DatabaseColumn(name: "Column A", type: .string, id: DatabaseColumn.mockID, tableID: DatabaseTable.mockID)
    }
    
    static func primaryKeyImage(isPrimary: Bool) -> Image {
        Image(systemName: isPrimary ? "key.fill" : "key")
    }
}

// MARK: - StoredByUser

// TODO: this may be unnecessary beacuse I can add a column with data type determined by a switch statement
protocol StoredByUser: Equatable, Hashable, Codable, CustomStringConvertible {
//    ///
//    /// - returns: nil if the value passed is nil, otherwise the result of running the constructor on the unwrapped value; implemented automatically using the required failable init
//    static func from(databaseValue: String?) -> Self?
//    init?(_ _: String)
}

extension StoredByUser {
//    static func from(databaseValue: String?) -> Self? {
//        if databaseValue == nil {
//            return nil
//        }
//        else {
//            return Self(databaseValue!)
//        }
//    }
}

extension Int: StoredByUser { }
extension String: StoredByUser { }
extension Bool: StoredByUser { }
extension Double: StoredByUser { }
// TODO: is a Tagged<Self, UUID> stored as itself or as a string/text? there's documentation on it somewhere
//extension Tagged<Database, UUID>: StoredByUser { }
extension Tagged<DatabaseTable, UUID>: StoredByUser { } // it has a constructor from a string, but it has a parameter label so it doesn't comply to the protocol
//extension Tagged<DatabaseColumn, UUID>: StoredByUser { }

// for converting from a raw value to what to store in the database
extension String {
    static func from(value: (any StoredByUser)?) -> String? {
        if value == nil {
            return nil
        }
        else {
            return String(describing: value!)
        }
    }
}

func valueFrom(databaseValue: String?, type: ValueType) -> (any StoredByUser)? {
    switch type {
    case .int:
        return Int(databaseValue ?? "")
    case .string:
        return databaseValue
    case .double:
        return Double(databaseValue ?? "")
    case .bool:
        return Bool(databaseValue ?? "")
    case .table:
        return DatabaseTable.ID(uuidString: databaseValue ?? "")
    }
}

// MARK: - DatabaseRow

// TODO: adding and removing a row can be done in the database, so this may not be necessary
struct DatabaseRow: Identifiable, Equatable, Hashable {
    public private(set) var id: Tagged<Self, UUID>
    // which DatabaseTable this is an instance of
    var tableID: DatabaseTable.ID
    // https://developer.apple.com/documentation/swift/dictionary
    // TODO: computed property that looks up data in the database
    // TODO: is this necessary?
    var values: Dictionary<DatabaseColumn.ID, DatabaseEntry>
    
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
                let entry = DatabaseEntry(rowID: self.id, columnID: column.id, value: nil)
                self.values[column.id] = entry
            }
        }
        self.tableID = tableID
    }
    
    func valueFor(columnID: DatabaseColumn.ID) -> (any StoredByUser)? {
        return values[columnID]?.value
    }
    
    ///
    /// if the row has this column, it will update its value. otherwise, it will add this column to its columns and give it the given value
    mutating func updateValueFor(columnID: DatabaseColumn.ID, newValue: (any StoredByUser)?) {
        if values[columnID] != nil {
            values[columnID]!.value = .from(value: newValue)
        }
        else {
            values[columnID] = DatabaseEntry(rowID: id, columnID: columnID, value: newValue)
        }
    }
    
    mutating func removeValueFor(columnID: DatabaseColumn.ID) {
        // assigning a dictionary's value for a given type sets it to nil
        values[columnID] = nil
    }
}

extension DatabaseRow {
    // TODO: empty as an instance method of the parent class instead? or even the addRow makes its own instead of using this
    static func empty(tableID: DatabaseTable.ID) -> DatabaseRow {
        return DatabaseRow(tableID: tableID)
    }
}

extension DatabaseRow: CustomStringConvertible {
    var description: String {
        return String(describing: id)
    }
}

// MARK: - DatabaseEntry

// TODO: deal with data directly with the database so this is unnecessary
struct DatabaseEntry: Identifiable {
    public private(set) var id: Tagged<Self, UUID>
    var rowID: DatabaseRow.ID
    var columnID: DatabaseColumn.ID
    // TODO: can I make this like a Byte type that is just stored in the database as bits?
    var value: String?
    
    init(rowID: DatabaseRow.ID, columnID: DatabaseColumn.ID, value: (any StoredByUser)?, id: Self.ID? = nil) {
        self.rowID = rowID
        self.columnID = columnID
        self.value = String.from(value: value)
        if let id {
            self.id = id
        }
        else {
            self.id = Self.ID(UUID())
        }
    }
}

extension DatabaseEntry: Equatable, Hashable {
    static func == (lhs: DatabaseEntry, rhs: DatabaseEntry) -> Bool {
        return lhs.rowID == rhs.rowID && lhs.columnID == rhs.columnID
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        rowID.hash(into: &hasher)
        columnID.hash(into: &hasher)
    }
}

// MARK: - GRDB setup

// TODO: refactor to remove DatabaseRow and DatabaseEntry
extension Database: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let tables = hasMany(DatabaseTable.self, using: DatabaseTable.databaseForeignKey)
    enum Columns {
        static let name = Column(CodingKeys.name)
    }
}

extension DatabaseTable: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case shouldShow
        case databaseID
    }
    
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
    
    static let associatedTableForeignKey = ForeignKey(["associatedTableID"])
    static let associatedTable = hasOne(DatabaseTable.self, using: associatedTableForeignKey)
    
    enum Columns {
        static let name = Column(CodingKeys.name)
        static let isPrimary = Column(CodingKeys.isPrimary)
        static let type = Column(CodingKeys.type)
    }
}

extension DatabaseRow: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let tableForeignKey = ForeignKey(["tableID"])
    static let table = belongsTo(DatabaseTable.self, using: tableForeignKey)
    
    // TODO: does this need to have a different using to look up by DatabaseColumn ID?
    static let columns = hasMany(DatabaseEntry.self, using: DatabaseEntry.rowForeignKey)
}

extension DatabaseEntry: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let rowForeignKey = ForeignKey(["rowID"])
    static let row = belongsTo(DatabaseRow.self, using: rowForeignKey)
    
    enum Columns {
        static let value = Column(CodingKeys.value)
    }
}

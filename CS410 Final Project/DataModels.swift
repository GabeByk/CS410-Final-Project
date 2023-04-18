//
//  DataModels.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections
// used for the DatabaseTable and DatabaseColumn's static properties for their images
import SwiftUI
import GRDB

// TODO: pressing the add button on any menu no longer allows adding multiple (databases, tables and, columns); this is because it's not linked to the database and another is created with ID -2
// TODO?: can the constructor automatically add the item to the database so the id is never nil and/or is that a good idea?
// TODO?: can GRDB deal with Tagged<Self, Int64> as ID's data type and/or is that a good idea?

struct Database: Identifiable {
    public private(set) var id: Int64?
    var name: String
    // TODO: use GRDB to store and access Database.tables
    var tables: IdentifiedArrayOf<DatabaseTable> {
        return (try? SchemaDatabase.shared.tablesFor(databaseID: id)) ?? []
    }
    
    init(name: String, id: Int64? = nil) {
        self.name = name
        self.id = id
        // TODO: we want to use an environment variable or something instead of SchemaDatabase.shared so that a user could use their own database
        try? SchemaDatabase.shared.addDatabase(&self)
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
        return Database(name: "Database A", id: -1)
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
    public private(set) var id: Int64?
    // which database this belongs to
    var databaseID: Int64
    
    enum PrimaryKey: Equatable, Hashable {
        case id(DatabaseTable.ID)
        case column(DatabaseColumn)
        case columns([DatabaseColumn])
    }
    
    var name: String
    // TODO: remove rows
    var rows: IdentifiedArrayOf<DatabaseRow> {
        return []
    }
    
    // TODO: use GRDB to access columns
    var columns: IdentifiedArrayOf<DatabaseColumn> {
        return (try? SchemaDatabase.shared.columnsFor(tableID: id)) ?? []
    }
    
    // TODO?: is this functionality necessary? having to show helper tables to work on them and add data will be kind of annoying
    var shouldShow: Bool
    
    init(name: String, shouldShow: Bool = true, id: Int64? = nil, columns: IdentifiedArrayOf<DatabaseColumn> = [], rows: IdentifiedArrayOf<DatabaseRow> = [], databaseID: Int64) {
        self.name = name
        self.shouldShow = shouldShow
        self.id = id
        self.databaseID = databaseID
        try? SchemaDatabase.shared.addTable(&self)
    }
    
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
        }
    }
    
    mutating func removeColumn(_ column: DatabaseColumn) {
        var myColumn = column
        try? SchemaDatabase.shared.removeColumn(&myColumn)
        for var instance in rows {
            if let id = column.id {
                instance.removeValueFor(columnID: id)
            }
        }
    }
    
    mutating func removeColumns(at offsets: IndexSet) {
        for index in offsets {
            let column = columns[index]
            removeColumn(column)
        }
    }
    
    mutating func addColumn(_ column: DatabaseColumn) {
        var myColumn = column
        try? SchemaDatabase.shared.addColumn(&myColumn)
        for var instance in rows {
            if let id = column.id {
                instance.updateValueFor(columnID: id, newValue: nil)
            }
        }
    }
    
    mutating func addInstance() {
        // TODO: add an instance to the table
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
    static func empty(databaseID: Int64) -> DatabaseTable {
        return DatabaseTable(name: "", databaseID: databaseID)
    }
    
    static var mockDatabaseTable: DatabaseTable {
        return DatabaseTable(name: "Table A", id: -1, columns: [.mockColumn], databaseID: -1)
    }
    
    static func shouldShowImage(shouldShow: Bool) -> Image {
        Image(systemName: shouldShow ? "key.fill" : "key")
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
    public private(set) var id: Int64?
    // whether this column is part of the primary key for its table. a column should be marked as primary if the value of all primary columns for a table are enough to uniquely determine which row has those values.
    var isPrimary: Bool
    // the title of this column
    var name: String
    // which data type this column should hold
    var type: ValueType
    // if type is .table, which DatabaseTable this DatabaseColumn holds
    var associatedTableID: Int64?
    // which DatabaseTable holds this column
    var tableID: Int64
    
    init(name: String, type: ValueType, isPrimary: Bool = false, id: Int64? = nil, tableID: Int64) {
        self.name = name
        self.type = type
        self.isPrimary = isPrimary
        self.id = id
        self.tableID = tableID
        try? SchemaDatabase.shared.addColumn(&self)
    }
    
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
        }
    }
}

extension DatabaseColumn {
    var valueType: String {
        return type.rawValue
    }
    
    static func empty(tableID: Int64) -> DatabaseColumn {
        return DatabaseColumn(name: "", type: .string, tableID: tableID)
    }
    
    static var mockColumn: DatabaseColumn {
        return DatabaseColumn(name: "Column A", type: .string, id: -1, tableID: -1)
    }
    
    static func primaryKeyImage(isPrimary: Bool) -> Image {
        Image(systemName: isPrimary ? "key.fill" : "key")
    }
}

// MARK: - StoredValue

// TODO: this may be unnecessary
protocol StoredValue: Equatable, Hashable, Codable, CustomStringConvertible {
    ///
    /// - returns: nil if the value passed is nil, otherwise the result of running the constructor on the unwrapped value; implemented automatically using the required failable init
    static func from(databaseValue: String?) -> Self?
    init?(_ _: String)
}

extension StoredValue {
    static func from(databaseValue: String?) -> Self? {
        if databaseValue == nil {
            return nil
        }
        else {
            return Self(databaseValue!)
        }
    }
}

extension Int: StoredValue { }
extension String: StoredValue { }
extension Bool: StoredValue { }
extension Double: StoredValue { }
extension Int64: StoredValue { }

// for converting from a raw value to what to store in the database
extension String {
    static func from(value: (any StoredValue)?) -> String? {
        if value == nil {
            return nil
        }
        else {
            return String(describing: value!)
        }
    }
}

func valueFrom(databaseValue: String?, type: ValueType) -> (any StoredValue)? {
    switch type {
    case .int:
        return Int.from(databaseValue: databaseValue)
    case .string:
        return String.from(databaseValue: databaseValue)
    case .double:
        return Double.from(databaseValue: databaseValue)
    case .bool:
        return Bool.from(databaseValue: databaseValue)
    case .table:
        return Int64.from(databaseValue: databaseValue)
    }
}

// MARK: - DatabaseRow

// TODO: deal with data directly with the database so this is unnecessary
struct DatabaseRow: Identifiable, Equatable, Hashable {
    public private(set) var id: Int64?
    // which DatabaseTable this is an instance of
    var tableID: Int64
    // https://developer.apple.com/documentation/swift/dictionary
    // TODO: use GRDB to access Columns by DatabaseColumn ID (if possible?)
    var columns: Dictionary<Int64, DatabaseEntry>
    
    init(columns: IdentifiedArrayOf<DatabaseColumn>? = nil, id: Int64? = nil, tableID: Int64) {
        self.id = id
        self.columns = [:]
        if let columns {
            for column in columns {
                
                #warning("defaulting rowID and columnID to -2 in DatabaseRow.init")
                let column = DatabaseEntry(rowID: id ?? -2, columnID: column.id ?? -2, value: nil)
                self.columns[column.id ?? -2] = column
            }
        }
        self.tableID = tableID
    }
    
    func valueFor(columnID: Int64) -> (any StoredValue)? {
        return columns[columnID]?.value
    }
    
    ///
    /// if the ID has not already been set, set it to the given ID.
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
        }
    }
    
    ///
    /// if the row has this column, it will update its value. otherwise, it will add this column to its columns and give it the given value
    mutating func updateValueFor(columnID: Int64, newValue: (any StoredValue)?) {
        if columns[columnID] != nil {
            columns[columnID]!.value = .from(value: newValue)
        }
        else {
            columns[columnID] = DatabaseEntry(rowID: id ?? -2, columnID: columnID, value: newValue)
        }
    }
    
    mutating func removeValueFor(columnID: Int64) {
        // assigning a dictionary's value for a given type sets it to nil
        columns[columnID] = nil
    }
}

extension DatabaseRow {
    // TODO: empty as an instance method of the parent class instead? or even the addRow makes its own instead of using this
    static func empty(tableID: Int64) -> DatabaseRow {
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
    public private(set) var id: Int64?
    var rowID: Int64
    var columnID: Int64
    // TODO: can I make this like a Byte type that is just stored in the database as bits?
    var value: String?
    
    init(rowID: Int64, columnID: Int64, value: (any StoredValue)?) {
        self.rowID = rowID
        self.columnID = columnID
        self.value = String.from(value: value)
    }

    /// if the ID has not already been set, set it to the given ID.
    mutating func initializeID(to id: Int64) {
        if self.id == nil {
            self.id = id
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

extension Database: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let tables = hasMany(DatabaseTable.self, using: DatabaseTable.databaseForeignKey)
    enum Columns {
        static let name = Column(CodingKeys.name)
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
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
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
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
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension DatabaseRow: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let tableForeignKey = ForeignKey(["tableID"])
    static let table = belongsTo(DatabaseTable.self, using: tableForeignKey)
    
    // TODO: does this need to have a different using to look up by DatabaseColumn ID?
    static let columns = hasMany(DatabaseEntry.self, using: DatabaseEntry.rowForeignKey)
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension DatabaseEntry: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
    static let rowForeignKey = ForeignKey(["rowID"])
    static let row = belongsTo(DatabaseRow.self, using: rowForeignKey)
    
    enum Columns {
        static let value = Column(CodingKeys.value)
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

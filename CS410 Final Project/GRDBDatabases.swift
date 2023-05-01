//
//  GRDBDatabases.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 4/10/23.
//

import Foundation
import GRDB
import IdentifiedCollections

/// The database used to store the schemas of all the databases
struct SchemaDatabase {
    
    init (_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }
    
    func allDatabases() -> IdentifiedArrayOf<Database> {
        do {
            // fetch the databases
            let databases: [Database] = try dbWriter.read { db in
                try Database.fetchAll(db)
            }
            
            // convert to identified array
            var identifiedDatabases: IdentifiedArrayOf<Database> = []
            for database in databases {
                identifiedDatabases.append(database)
            }
            return identifiedDatabases
        }
        catch {
            print(error)
            return []
        }
    }
    
    func database(id: Database.ID) -> Database? {
        do {
            let databases: [Database] = try dbWriter.read { db in
                try Database.fetchAll(db)
                    .filter { database in
                        database.id == id
                    }
            }
            return databases.first
        }
        catch {
            print(error)
            return nil
        }
    }
    
    func addDatabase(_ database: Database) {
        // insert is marked as mutating, but because we no longer use an autoincrementing primary key, it doesn't actually mutate the value
        // also, this is called when exiting edit mode, after which the local data is synced with the database, so if it does actually get mutated it should pull the changes from here
        // if it turns out it does mutate localDatabase in a meaningful way, database should be an inout parameter so its value is changed
        var localDatabase = database
        do {
            try dbWriter.write() { db in
                try localDatabase.insert(db)
            }
        }
        catch {
            print(error)
        }
    }
    
    func removeDatabase(_ database: Database) {
        do {
            try dbWriter.write() { db in
                // delete returns whether it worked, so we got a warning saying it was unused if we don't do anything with it
                let _ = try database.delete(db)
            }
            DataDatabase.deleteDataFor(databaseID: database.id)
        }
        catch {
            print(error)
        }
    }
    
    func updateDatabase(_ database: Database) {
        do {
            try dbWriter.write() { db in
                try database.update(db)
            }
        }
        catch {
            print(error)
        }
    }
    
    func allTables() -> IdentifiedArrayOf<DatabaseTable> {
        do {
            // fetch the tables
            let tables: [DatabaseTable] = try dbWriter.read { db in
                try DatabaseTable.fetchAll(db)
            }
            
            // convert to an identified array
            var identifiedTables: IdentifiedArrayOf<DatabaseTable> = []
            for table in tables {
                identifiedTables.append(table)
            }
            return identifiedTables
        }
        catch {
            print(error)
            return []
        }
    }
    
    func tablesFor(databaseID: Database.ID) -> IdentifiedArrayOf<DatabaseTable> {
        do {
            // fetch the tables
            let tables: [DatabaseTable] = try dbWriter.read { db in
                try DatabaseTable.fetchAll(db)
                    .filter { table in
                        table.databaseID == databaseID
                    }
            }
            
            // convert to identified array
            var identifiedTables: IdentifiedArrayOf<DatabaseTable> = []
            for table in tables {
                identifiedTables.append(table)
            }
            return identifiedTables
        }
        catch {
            print(error)
            return []
        }
    }
    
    func table(id: DatabaseTable.ID) -> DatabaseTable? {
        do {
            let tables: [DatabaseTable] = try dbWriter.read { db in
                try DatabaseTable.fetchAll(db)
                    .filter { table in
                        table.id == id
                    }
            }
            return tables.first
        }
        catch {
            return nil
        }
    }
    
    func addTable(_ table: DatabaseTable) {
        do {
            var localTable = table
            try dbWriter.write() { db in
                try localTable.insert(db)
            }
            let db = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
            db.addTable(table)
        }
        catch {
            print(error)
        }
    }
    
    func removeTable(_ table: DatabaseTable) {
        do {
            let _ = try dbWriter.write() { db in
                try table.delete(db)
            }
            let db = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
            db.removeTable(table)
        }
        catch {
            print(error)
        }
    }
    
    func updateTable(_ table: DatabaseTable) {
        do {
            try dbWriter.write() { db in
                try table.update(db)
            }
        }
        catch {
            print(error)
        }
    }
    
    func allColumns() -> IdentifiedArrayOf<DatabaseColumn> {
        do {
            // fetch the columns
            let columns: [DatabaseColumn] = try dbWriter.read { db in
                try DatabaseColumn.fetchAll(db)
            }
            
            // convert to identified array
            var identifiedColumns: IdentifiedArrayOf<DatabaseColumn> = []
            for column in columns {
                identifiedColumns.append(column)
            }
            return identifiedColumns
        }
        catch {
            print(error)
            return []
        }
    }
    
    func columnsFor(tableID: DatabaseTable.ID) -> IdentifiedArrayOf<DatabaseColumn> {
        do {
            // fetch the columns
            let columns: [DatabaseColumn] = try dbWriter.read { db in
                try DatabaseColumn.fetchAll(db)
                    .filter { column in
                        column.tableID == tableID
                    }
            }
            
            // convert to identified array
            var identifiedColumns: IdentifiedArrayOf<DatabaseColumn> = []
            for column in columns {
                identifiedColumns.append(column)
            }
            return identifiedColumns
        }
        catch {
            return []
        }
    }
    
    func column(id: DatabaseColumn.ID) -> DatabaseColumn? {
        do {
            let columns: [DatabaseColumn] = try dbWriter.read { db in
                try DatabaseColumn.fetchAll(db)
                    .filter { column in
                        column.id == id
                    }
            }
            return columns.first
        }
        catch {
            return nil
        }
    }
    
    func addColumn(_ column: DatabaseColumn) {
        do {
            var local = column
            // update the disc database first so it can have both the old value and the new value
            if let table = table(id: local.tableID) {
                let db = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
                db.addColumn(local)
            }
            try dbWriter.write() { db in
                try local.insert(db)
            }
        }
        catch {
            print(error)
        }
    }
    
    func removeColumn(_ column: DatabaseColumn) {
        do {
            if let table = table(id: column.tableID) {
                let db = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
                db.removeColumn(column)
            }
            let _ = try dbWriter.write() { db in
                try column.delete(db)
            }
        }
        catch {
            print(error)
        }
    }
    
    func updateColumn(_ column: DatabaseColumn) {
        do {
            if let table = table(id: column.tableID) {
                let db = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
                db.updateColumn(column)
            }
            try dbWriter.write() { db in
                try column.update(db)
            }
        }
        catch {
            print(error)
        }
    }

    /// The DatabaseMigrator that defines the database schema.
       ///
       /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations>
       private var migrator: DatabaseMigrator {
           var migrator = DatabaseMigrator()

           #if DEBUG
           // Speed up development by nuking the database when migrations change
           // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations>
           migrator.eraseDatabaseOnSchemaChange = true
           #endif

           migrator.registerMigration("createDataModels") { db in
               // Create a table
               // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseschema>
               try db.create(table: "database") { t in
                   t.primaryKey("id", .blob)
                   t.column("name", .text).notNull()
               }
               
               try db.create(table: "databaseTable") { t in
                   t.primaryKey("id", .blob)
                   t.column("databaseID", .integer)
                       .notNull()
                       .indexed()
                       .references("database", onDelete: .cascade)
                   t.column("name", .text)
                   t.column("shouldShow", .boolean)
               }
               
               try db.create(table: "databaseColumn") { t in
                   t.primaryKey("id", .blob)
                   t.column("tableID", .integer)
                       .notNull()
                       .indexed()
                       .references("databaseTable", onDelete: .cascade)
                   t.column("referencedTableID", .integer)
                       .indexed()
                       .references("databaseTable", onDelete: .setNull)
                   t.column("name", .text)
                   t.column("isPrimary", .boolean)
                   t.column("type", .text)
               }
           }
           
           // Migrations for future application versions will be inserted here:
           // migrator.registerMigration(...) { db in
           //     ...
           // }
           return migrator
       }

    
    /// Provides access to the database.
    ///
    /// Application can use a `DatabasePool`, while SwiftUI previews and tests
    /// can use a fast in-memory `DatabaseQueue`.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections>
    private let dbWriter: any DatabaseWriter
}

// from https://github.com/dave256/GRDBDemo/blob/main/GRDBDemo/AppDatabase.swift
extension SchemaDatabase {
    /// The database the application uses to store the schema. For your own directory/sqlite file, mimic makeDefaultDatabase and replace this with it.
    static var used = makeDefaultDatabase()

    private static func makeDefaultDatabase() -> SchemaDatabase {
        do {
            // Pick a folder for storing the SQLite database, as well as
            // the various temporary files created during normal database
            // operations (https://sqlite.org/tempfiles.html).
            let fileManager = FileManager()
            let folderURL = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("schemas", isDirectory: true)

            // Support for tests: delete the database if requested
            if CommandLine.arguments.contains("-reset") {
                try? fileManager.removeItem(at: folderURL)
            }

            // Create the database folder if needed
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            // Connect to a database on disk
            // See https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections
            let dbURL = folderURL.appendingPathComponent("schema.sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)

            // Create the SchemaDatabase
            let appDatabase = try SchemaDatabase(dbPool)
            
            return appDatabase
        } catch {
            // TODO: Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate.
            //
            // Typical reasons for an error here include:
            // * The parent directory cannot be created, or disallows writing.
            // * The database is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The database could not be migrated to its latest schema version.
            // Check the error message to determine what the actual problem was.
            fatalError("Unresolved error \(error)")
        }
    }

    /// Creates an empty database for SwiftUI previews
    static func empty() -> SchemaDatabase {
        // Connect to an in-memory database
        // See https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections
        let dbQueue = try! DatabaseQueue()
        return try! SchemaDatabase(dbQueue)
    }
}

/// One of these objects manages the information for an entry in the SchemaDatabase's database table
struct DataDatabase {
    let databaseID: Database.ID
    
    init(databaseID: Database.ID, _ dbWriter: any DatabaseWriter) {
        self.databaseID = databaseID
        self.dbWriter = dbWriter
    }
    
    func rowsFor(table: DatabaseTable) -> IdentifiedArrayOf<DatabaseRow> {
        // get all the rows
        var rows: [DatabaseRow] = []
        do {
            rows = try dbWriter.read { db in
                // something like:
                // try DatabaseRow.fetchAll(db, sql: "SELECT * FROM ?", arguments: ["'\(table.id)'"])
                // would be nice, but i get a syntax error
                try DatabaseRow.fetchAll(db, sql: "SELECT * FROM '\(table.id)'")
            }
        } catch {
            print(error)
        }
        
        // convert to identified array
        var identifiedRows: IdentifiedArrayOf<DatabaseRow> = []
        for row in rows {
            identifiedRows.append(row)
        }
        return identifiedRows
    }

    func allRows() -> IdentifiedArrayOf<DatabaseRow> {
        let tables = SchemaDatabase.used.tablesFor(databaseID: databaseID)
        var rows: IdentifiedArrayOf<DatabaseRow> = []
        for table in tables {
            rows += rowsFor(table: table)
        }
        return rows
    }
    
    func row(rowID: DatabaseRow.ID) -> DatabaseRow? {
        return allRows()[id: rowID]
    }
    
    func row(rowID: DatabaseRow.ID, tableID: DatabaseTable.ID) -> DatabaseRow? {
        var row = DatabaseRow(id: rowID, tableID: tableID)
        do {
            // get the table for the specified id
            if let table = SchemaDatabase.used.table(id: tableID) {
                let columns = table.columns
                // get the row for this id
                if let databaseRow = try dbWriter.read({ db in
                    try Row.fetchOne(db,
                                     sql: "SELECT * FROM '\(tableID)' WHERE id = ?",
                                     arguments: [rowID.databaseValue])
                    
                })
                // if the row exists, fill row.values with the values from the database
                {
                    for column in columns {
                        let newValue: StoredValue
                        switch column.type {
                        // simple for everything but table
                        case .int:
                            let value: Int? = databaseRow["\(column.id)"]
                            newValue = .int(value)
                        case .string:
                            let value: String? = databaseRow["\(column.id)"]
                            newValue = .string(value)
                        case .bool:
                            let value: Bool? = databaseRow["\(column.id)"]
                            newValue = .bool(value)
                        case .double:
                            let value: Double? = databaseRow["\(column.id)"]
                            newValue = .double(value)
                        // for a table, we need to convert from the DatabaseValue that's stored
                        case .table:
                            // this only returns nil if the column doesn't exist
                            let value: DatabaseValue? = databaseRow["\(column.id)"]
                            // if the column exists, try to get the ID
                            if let value {
                                // if we can convert this to a UUID, put it in the row
                                if let rawID = UUID.fromDatabaseValue(value) {
                                    newValue = .row(referencedRowID: DatabaseRow.ID(rawID), referencedTableID: column.referencedTableID)
                                }
                                // otherwise, say it's nil
                                else {
                                    newValue = .row(referencedRowID: nil, referencedTableID: column.referencedTableID)
                                }
                            }
                            // if the column doesn't exist, say it's nil
                            else {
                                newValue = .row(referencedRowID: nil, referencedTableID: column.referencedTableID)
                            }
                        }
                        row.updateValueFor(columnID: column.id, newValue: newValue)
                    }
                }
            }
            return row
        }
        catch {
            print(error)
            return nil
        }
    }
    
    func argumentsFor(row: DatabaseRow) -> (columnNames: String, labels: String, arguments: StatementArguments)? {
        if let table = SchemaDatabase.used.table(id: row.tableID) {
            // programatically determine the syntax to match https://github.com/groue/GRDB.swift#executing-updates
            // goal: INSERT INTO \(table.id) ([each column name separated by columns]) VALUES ([each value for the column])
            // example: sql: "INSERT INTO player (name, score) VALUES (?, ?)", arguments: ["Barbara", 1000]
            
            // this is what would be "name, score" in the example
            var columnNames = "id, tableID"
            // this would be ":name, :score"
            var prefixes = ":id, :tableID"
            // this would be ["name": name, "score": 1000]
            var arguments: StatementArguments = ["id": row.id.databaseValue, "tableID": row.tableID.databaseValue]
            for i in 0..<table.columns.count {
                let column = table.columns[i]
                // the column's name in the database is its id
                columnNames += ", '\(column.id)'"
                // identify each column in the parameters by its current index
                // we might not get the same prefix for each column each time, labels and arguments match, so it shouldn't matter
                let prefix = String(i)
                prefixes += ", :\(prefix)"
                // the raw value that we should insert in the database
                let argument: StatementArguments
                // if we have a value, extract the associated data and insert it
                if let value = row.values[column.id] {
                    switch value {
                    case .bool(let b):
                        argument = [prefix: b]
                    case .double(let d):
                        argument = [prefix: d]
                    case .int(let i):
                        argument = [prefix: i]
                    case .string(let s):
                        argument = [prefix: s]
                    case .row(let referencedRowID, _):
                        argument = [prefix: referencedRowID?.databaseValue]
                    }
                }
                // otherwise, just add nil
                else {
                    argument = [prefix: nil]
                }
                arguments += argument
            }
            return (columnNames, prefixes, arguments)
        }
        return nil
    }
    
    func addRow(_ row: DatabaseRow) {
        do {
            if let (columnNames, labels, arguments) = argumentsFor(row: row) {
                // insert the data into the database
                try dbWriter.write { db in
                    try db.execute(sql: """
                                    INSERT INTO '\(row.tableID)'
                                    (\(columnNames)) VALUES
                                    (\(labels))
                                    """,
                                   arguments: arguments
                    )
                }
            }
        } catch {
            print(error)
        }
    }
    
    func updateRow(_ row: DatabaseRow) {
        do {
            if let (columnNames, labels, arguments) = argumentsFor(row: row) {
                // we want to pass everything but the id and tableID to set
                let fixedLabels = labels.split(separator: ", ").dropFirst(2).joined(separator: ", ")
                let fixedColumnNames = columnNames.split(separator: ", ").dropFirst(2).joined(separator: ", ")
                
                // convert to the format of "abc = :xyz"; abc is in columnNames, :xyz is in labels
                var parameters = ""
                let labelList = fixedLabels.split(separator: ", ")
                let columnList = fixedColumnNames.split(separator: ", ")
                for i in 0..<columnList.count {
                    if i > 0 {
                        parameters += ", "
                    }
                    parameters += "\(columnList[i]) = \(labelList[i])"
                }
                
                // run SQL to update the row
                try dbWriter.write { db in
                    try db.execute(sql: """
                                        UPDATE '\(row.tableID.uuidString)'
                                        SET \(parameters)
                                        WHERE id = :id
                                        """,
                                   arguments: arguments)
                }
            }
        } catch {
            print(error)
        }
    }
    
    func removeRow(_ row: DatabaseRow) {
        do {
            try dbWriter.write { db in
                try db.execute(sql: "DELETE FROM '\(row.tableID)' WHERE id = ?", arguments: [row.id.databaseValue])
            }
        } catch {
            // TODO: show pop-up saying delete failed ("FOREIGN KEY constraint failed - while executing ..."
            // something like "Cannot delete row [abc], [def] in table [ghi] uses it"
            print(error)
        }
    }
    
    /// Add the requested table to the database
    func addTable(_ table: DatabaseTable) {
        // run SQL to add the table
        do {
            try dbWriter.write { db in
                try db.create(table: "\(table.id)") { t in
                    // the ID of rows in this table is a DatabaseRow.ID
                    t.primaryKey("id", .blob)
                    t.column("tableID", .blob)
                }
            }
        }
        catch {
            print(error)
        }
    }
    
    /// Remove the requested table from the database
    func removeTable(_ table: DatabaseTable) {
        // run SQL to remove the table
        do {
            try dbWriter.write { db in
                try db.drop(table: "\(table.id)")
            }
        }
        catch {
            print(error)
        }
    }
    
    /// Add the given column to the table with the ID that matches the column's tableID property
    func addColumn(_ column: DatabaseColumn) {
        // run SQL to add the column
        do {
            try dbWriter.write { db in
                try db.alter(table: "\(column.tableID)") { t in
                    // whether we added the column, since the table case requires extra information
                    // this could be a let that's set false in every other case, but this is more convenient
                    var columnAdded = false
                    // what data type the column should be
                    let dataType: GRDB.Database.ColumnType
                    switch column.type {
                    case .table:
                        dataType = .blob
                        // if the column should reference another table, set it up so it does
                        if let otherTableID = column.referencedTableID {
                            t.add(column: "\(column.id)", dataType)
                                .references("\(otherTableID)")
                            columnAdded = true
                        }
                    case .int:
                        dataType = .integer
                    case .string:
                        dataType = .text
                    case .bool:
                        dataType = .boolean
                    case .double:
                        dataType = .double
                    }
                    // we don't want to add the column if we already did in .table
                    if !columnAdded {
                        t.add(column: "\(column.id)", dataType)
                    }
                }
            }
        }
        catch {
            print(error)
        }
    }
    
    /// Remove the given column from the table with the ID that matches the column's tableID property
    func removeColumn(_ column: DatabaseColumn) {
        // run SQL to remove the column
        do {
            try dbWriter.write { db in
                try db.alter(table: "\(column.tableID)") { t in
                    t.drop(column: "\(column.id)")
                }
            }
        }
        catch {
            print(error)
        }
    }
    
    /// Update the given column in the table with the ID that matches the column's tableID property
    /// Updates the column by removing the existing column and adding it again, but only if the data type is different, so no data is lost from renaming a column
    func updateColumn(_ newColumn: DatabaseColumn) {
        // run SQL to update the column
        if let oldColumn = SchemaDatabase.used.column(id: newColumn.id) {
            // only update the column if the data type is different; this way renaming a column doesn't wipe out the data
            if oldColumn.type != newColumn.type ||
                // we also want to update the table if we changed which table the column is referencing
                (oldColumn.type == newColumn.type && newColumn.type == .table && oldColumn.referencedTableID != newColumn.referencedTableID) {
                // TODO: is there a better way to update the column (e.g. to change the data type)? I don't think there is
                // TODO: try to convert the data in existing rows for this column to the new data type, except for .table
                removeColumn(newColumn)
                addColumn(newColumn)
            }
        }
        else {
            addColumn(newColumn)
        }
    }
    
    private let dbWriter: any DatabaseWriter
}

extension DataDatabase {
    private static func urlFor(databaseID id: Database.ID) throws -> URL {
        let fileManager = FileManager()
        let folderURL = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        // this DB's files should be inside the databases/id directory
            .appendingPathComponent("databases", isDirectory: true)
            .appendingPathComponent("\(id)", isDirectory: true)
        return folderURL
    }
    
    /// Creates an instance connected to the Database object with the given ID.
    static func discDatabaseFor(databaseID id: Database.ID) -> DataDatabase {
        do {
            // Choose folder
            let fileManager = FileManager()
            let folderURL = try urlFor(databaseID: id)
            
            // Create the folder if it doesn't exist
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            // Connect to the disc database
            // See https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections
            let dbURL = folderURL.appendingPathComponent("\(id).sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)
            
            // Create the requested DataDatabase object
            let database = DataDatabase(databaseID: id, dbPool)
            return database
        }
        catch {
            // TODO: Replace this implementation with code to handle the error appropriately.
            fatalError("Unresolved error \(error)")
        }
    }
        
    /// removes all data for the specified database from the disc
    static func deleteDataFor(databaseID id: Database.ID) {
        // https://developer.apple.com/documentation/foundation/filemanager/1413590-removeitem
        do {
            let fileManager = FileManager()
            let folderURL = try urlFor(databaseID: id)
            try fileManager.removeItem(at: folderURL)
        }
        catch {
            if error is CocoaError {
                print(error.localizedDescription)
            }
            else {
                print(error)
            }
        }
    }
}

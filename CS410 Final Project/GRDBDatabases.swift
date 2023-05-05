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
    
    /// - returns: every database we have
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
    
    /// - parameter id: the ID of the database to retrieve from disc
    /// - returns: the first database we have with this id, or nil if no database with this id exists
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
    
    /// adds the given database to this schema database
    /// - parameter database: the database to add on disc
    func addDatabase(_ database: Database) {
        // insert is marked as mutating, but because we aren't using an autoincrementing primary key, it doesn't seem to actually mutate the value
        // also, this is called when exiting edit mode, after which the local data is synced with the database, so if it does actually get mutated it should pull the changes immeditately afterwards
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
    
    /// removes the given database from the database on disc
    /// - parameter database: the database to remove
    func removeDatabase(_ database: Database) {
        do {
            try dbWriter.write() { db in
                // delete returns whether it worked, so not assinging the return value resulted in a warning
                let _ = try database.delete(db)
            }
            // also remove the database we deleted from the disc
            UserDatabase.deleteDataFor(databaseID: database.id)
        }
        catch {
            print(error)
        }
    }
    
    /// updates the database on disc to match the given database
    /// - parameter database: the database with the updated values
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
    
    /// - returns: every table we have in the app
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
    
    /// - parameter databaseID: the ID of the database to fetch tables for
    /// - returns: every table belonging to the database with the given ID
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
    
    /// - parameter id: the ID to fetch a table for
    /// - returns: the first table with the given ID, or nil if no table has this ID
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
    
    /// adds the given table to the database on disc
    /// - parameter table: the table to add to the database
    func addTable(_ table: DatabaseTable) {
        do {
            // again, I don't believe localTable is mutated, but table should be an inout parameter if it is
            var localTable = table
            try dbWriter.write() { db in
                try localTable.insert(db)
            }
            // also add the table to the disc database for its database
            let db = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
            db.addTable(table)
        }
        catch {
            print(error)
        }
    }
    
    /// removes the given table from the database on disc
    /// - parameter table: the table to remove
    func removeTable(_ table: DatabaseTable) {
        do {
            try dbWriter.write() { db in
                // delete returns whether it worked, which is information we don't need
                let _ = try table.delete(db)
            }
            // also remove the table from the database on disc
            let db = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
            db.removeTable(table)
        }
        catch {
            print(error)
        }
    }
    
    /// updates the table on disc to match the given table's information
    /// - parameter table: the table with the updated information
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
    
    /// - returns: all columns we have in the database
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
    
    /// fetches all columns that belong to the table with the given ID
    /// - parameter tableID: the table to fetch columns for
    /// - returns: all columns that belong to the given table
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
    
    /// - returns: the first column on disc with the given ID, or nil if no such column exists
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
    
    /// adds the given column to the database on disc
    /// - parameter column: the column to add to the database
    func addColumn(_ column: DatabaseColumn) {
        do {
            // again, if local is mutated, column needs to be inout
            var local = column
            
            // the updateColumn method needs the disc database to be updated first, so the other column methods also update it first
            if let table = table(id: local.tableID) {
                let db = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
                db.addColumn(local)
            }
            
            // now insert the column to the database
            try dbWriter.write() { db in
                try local.insert(db)
            }
        }
        catch {
            print(error)
        }
    }
    
    /// removes the given column from the database on disc
    /// - parameter column: the column to remove from the database
    func removeColumn(_ column: DatabaseColumn) {
        do {
            // updateColumn needs to update the disc database first, so this does to be consistent
            if let table = table(id: column.tableID) {
                let db = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
                db.removeColumn(column)
            }
            
            try dbWriter.write() { db in
                // delete returns whether it worked, which is info we don't need
                let _ = try column.delete(db)
            }
        }
        catch {
            print(error)
        }
    }
    
    /// updates the database on disc to hold the given column's information instead of the column it already has
    /// - parameter column: the column with the updated information
    func updateColumn(_ column: DatabaseColumn) {
        do {
            // update the disc database first so it can compare the new value to the old value
            if let table = table(id: column.tableID) {
                let db = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
                db.updateColumn(column)
            }
            
            // now replace the old value with the new one
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
               
               // table of databases the user creates
               try db.create(table: "database") { t in
                   t.primaryKey("id", .blob)
                   t.column("name", .text)
                       .notNull()
               }
               
               // table of tables the user adds to their databases
               try db.create(table: "databaseTable") { t in
                   t.primaryKey("id", .blob)
                   t.column("databaseID", .integer)
                       .notNull()
                       .indexed()
                       .references("database", onDelete: .cascade)
                   t.column("name", .text)
                   t.column("shouldShow", .boolean)
               }
               
               // table of columns the user adds to their tables
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

extension SchemaDatabase {
    /// The database the application uses to store the schema. For your own directory/sqlite file, mimic makeDefaultDatabase and set this variable equal to it.
    static var used = makeDefaultDatabase() ?? .empty()

    private static func makeDefaultDatabase() -> SchemaDatabase? {
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
            print(error)
            return nil
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
struct UserDatabase {
    // which database object this database is for
    let databaseID: Database.ID
    
    /// - parameter databaseID: the ID of the database to look up
    /// - returns: an instance connected to the sqlite file on disc for the Database object with the given ID.
    static func discDatabaseFor(databaseID id: Database.ID) -> UserDatabase {
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
            
            // Create the requested UserDatabase object
            let database = UserDatabase(databaseID: id, dbPool)
            return database
        }
        catch {
            // Typical reasons for an error here include:
            // * The parent directory cannot be created, or disallows writing.
            // * The database is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The database could not be migrated to its latest schema version.
            // Check the error message to determine what the actual problem was.
            print(error)
            return .empty(databaseID: id)
        }
    }
    
    /// Creates an empty database for SwiftUI previews
    static func empty(databaseID id: Database.ID) -> UserDatabase {
        // Connect to an in-memory database
        // See https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections
        let dbQueue = try! DatabaseQueue()
        return UserDatabase(databaseID: id, dbQueue)
    }
    
    /// removes all data for the specified database from the disc
    static func deleteDataFor(databaseID id: Database.ID) {
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
    
    func rowsFor(table: DatabaseTable) -> IdentifiedArrayOf<DatabaseRow> {
        // get all the rows
        var rows: [DatabaseRow] = []
        do {
            rows = try dbWriter.read { db in
                // something like:
                // try DatabaseRow.fetchAll(db, sql: "SELECT * FROM ?", arguments: ["'\(table.id)'"])
                // would be nice, but I get a syntax error from SQLite; I think you can't pass a table name as an argument this way
                // I'm not super concerned about sql-injection because table.id is a bunch of hex separated by single dashes, so it shouldn't be able to get out of its quotation marks, let alone run malicious SQL code, but it would still be nice to change it if GRDB adds support for it later
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
    
    /// - returns: all rows in this database; only used for debugging in CS410_Final_ProjectApp.swift
    func allRows() -> IdentifiedArrayOf<DatabaseRow> {
        let tables = SchemaDatabase.used.tablesFor(databaseID: databaseID)
        var rows: IdentifiedArrayOf<DatabaseRow> = []
        for table in tables {
            rows += rowsFor(table: table)
        }
        return rows
    }
    
    /// - parameter rowID: the ID of the row to retrieve
    /// - parameter tableID: the ID of the table to retrieve the row from
    /// - returns: the requested row, if it exists
    func row(rowID: DatabaseRow.ID, tableID: DatabaseTable.ID) -> DatabaseRow? {
        do {
            var row = DatabaseRow(id: rowID, tableID: tableID)
            let columns = SchemaDatabase.used.columnsFor(tableID: tableID)
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
                    // put the value for this column in the row
                    row.updateValueFor(columnID: column.id, newValue: newValue)
                }
            }
            return row
        }
        catch {
            print(error)
            return nil
        }
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
            // sometimes an error can happen that prevents it from being deleted (e.g. "FOREIGN KEY constraint failed - while executing ...")
            // a popup with something like "Cannot delete row [abc], [def] in table [ghi] uses it" would be nice to add
            print(error)
        }
    }
    
    /// Add the requested table to the database
    func addTable(_ table: DatabaseTable) {
        // run SQL to add the table
        do {
            try dbWriter.write { db in
                // the two columns every table has are a row's ID and a row's tableID
                // we could avoid storing the tableID in the database if we could somehow access the table's name while reading a row, but I wasn't able to figure out how to do it
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
                        // if the column should reference another table, set it up so it does; if it doesn't, the code after the switch will add it
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
                // I don't think there's a better way to alter a table to change the data type of a column, but we could save the old data and try to convert it to the new data type
                removeColumn(newColumn)
                addColumn(newColumn)
            }
        }
        else {
            addColumn(newColumn)
        }
    }
    
    private let dbWriter: any DatabaseWriter
    
    init(databaseID: Database.ID, _ dbWriter: any DatabaseWriter) {
        self.databaseID = databaseID
        self.dbWriter = dbWriter
    }
    
    /// - parameter databaseID: the database to determine a URL for
    /// - returns: a URL object set to the folder the database's sqlite file is in
    private static func urlFor(databaseID id: Database.ID) throws -> URL {
        let fileManager = FileManager()
        let folderURL = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        // this DB's files should be inside the databases/id directory
            .appendingPathComponent("databases", isDirectory: true)
            .appendingPathComponent("\(id)", isDirectory: true)
        return folderURL
    }
    
    
    /// programmatically determine the syntax to match https://github.com/groue/GRDB.swift#executing-updates
    /// goal: INSERT INTO \(table.id) ([each column name separated by commas]) VALUES ([each value for the column])
    /// example: sql: "INSERT INTO player (name, score) VALUES (:name, :score)", arguments: ["name": "Barbara", "score": 1000]
    /// - parameter row: the row to create arguments for
    /// - returns: columnNames would be "name, score", labels would be ":name, :score", and arguments would be ["name": "Barbara", "score": 1000] for the given example
    private func argumentsFor(row: DatabaseRow) -> (columnNames: String, labels: String, arguments: StatementArguments)? {
        if let table = SchemaDatabase.used.table(id: row.tableID) {
            // this would be "name, score" in the example
            var columnNames = "id, tableID"
            // this would be ":name, :score"
            var prefixes = ":id, :tableID"
            // this would be ["name": name, "score": 1000]
            var arguments: StatementArguments = ["id": row.id.databaseValue, "tableID": row.tableID.databaseValue]
            let columns = SchemaDatabase.used.columnsFor(tableID: table.id)
            for i in 0..<columns.count {
                let column = columns[i]
                // the column's name in the database is its id
                columnNames += ", '\(column.id)'"
                // identify each column in the parameters by its current index
                // we might not get the same prefix for each column each time this method is called, but labels and arguments match, so it shouldn't matter
                let prefix = String(i)
                prefixes += ", :\(prefix)"
                // the raw value that we should insert in the database
                let argument: StatementArguments
                // if we have a value, extract the associated data and insert it
                if let value = row.valueFor(columnID: column.id) {
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
}

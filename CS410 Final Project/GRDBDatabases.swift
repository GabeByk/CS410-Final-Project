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
    
    func allDatabases() throws -> IdentifiedArrayOf<Database> {
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
    
    func addDatabase(_ database: Database) throws {
        // insert is marked as mutating, but because we no longer use an autoincrementing primary key, it doesn't actually mutate the value
        // also, this is called when exiting edit mode, after which the local data is synced with the database, so if it does actually get mutated it should pull that
        // if it turns out it does mutate localDatabase in a meaningful way, database should be an inout parameter so its value is changed
        var localDatabase = database
        try dbWriter.write() { db in
            try localDatabase.insert(db)
        }
        print(localDatabase == database)
    }
    
    func removeDatabase(_ database: Database) throws {
        // TODO: why am I getting a warning "Result of call to 'write' is unused" but not in addDatabase or updateDatabase
        // if i just add 'print(db)' inside the body it seems happy; maybe delete isn't marked as using the database or something?
        try dbWriter.write() { db in
            try database.delete(db)
        }
    }
    
    func updateDatabase(_ database: Database) throws {
        try dbWriter.write() { db in
            try database.update(db)
        }
    }
    
    func allTables() throws -> IdentifiedArrayOf<DatabaseTable> {
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
    
    func tablesFor(databaseID: Database.ID) throws -> IdentifiedArrayOf<DatabaseTable> {
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
    
    func addTable(_ table: DatabaseTable) throws {
        var localTable = table
        try dbWriter.write() { db in
            try localTable.insert(db)
        }
    }
    
    func removeTable(_ table: DatabaseTable) throws {
        try dbWriter.write() { db in
            try table.delete(db)
        }
    }
    
    func updateTable(_ table: DatabaseTable) throws {
        try dbWriter.write() { db in
            try table.update(db)
        }
    }
    
    func allColumns() throws -> IdentifiedArrayOf<DatabaseColumn> {
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
    
    func columnsFor(tableID: DatabaseTable.ID) throws -> IdentifiedArrayOf<DatabaseColumn> {
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
    
    func addColumn(_ column: DatabaseColumn) throws {
        var local = column
        try dbWriter.write() { db in
            try local.insert(db)
        }
    }
    
    func removeColumn(_ column: DatabaseColumn) throws {
        try dbWriter.write() { db in
            try column.delete(db)
        }
    }
    
    func updateColumn(_ column: DatabaseColumn) throws {
        try dbWriter.write() { db in
            try column.update(db)
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
                   // TODO: how is a Tagged<Self, UUID> stored? reference documentation
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
                   t.column("associatedTableID", .integer)
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
    /// The database for the application
    static let shared = makeShared()

    private static func makeShared() -> SchemaDatabase {
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

            // Prepare the database with test fixtures if requested
//            if CommandLine.arguments.contains("-fixedTestData") {
//                try appDatabase.createPlayersForUITests()
//            } else {
//                // Otherwise, populate the database if it is empty, for better
//                // demo purpose.
//                try appDatabase.createRandomPlayersIfEmpty()
//            }
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
    
    // the number of transactions so each migration has a unique name
    var transactionCount: Int = 0
    
    init(databaseID: Database.ID, _ dbWriter: any DatabaseWriter) {
        self.databaseID = databaseID
        self.dbWriter = dbWriter
    }
    
    /// Add the requested table to the database
    mutating func addTable(_ table: DatabaseTable) {
        defer {
            transactionCount += 1
        }
        // run SQL to add the table
        var migrator = DatabaseMigrator()
            
        migrator.registerMigration("createTable\(table.id)\(transactionCount)") { db in
            try db.create(table: "\(table.id)") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
    }
    
    /// Remove the requested table from the database
    mutating func removeTable(_ table: DatabaseTable) {
        defer {
            transactionCount += 1
        }
        // run SQL to remove the table
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("removeTable\(table.id)\(transactionCount)") { db in
            try db.drop(table: "\(table.id)")
        }
    }
    
    /// Add the given column to the table with the ID that matches the column's tableID property
    mutating func addColumn(_ column: DatabaseColumn) {
        defer {
            transactionCount += 1
        }
        // run SQL to add the column
        var migrator = DatabaseMigrator()
            
        migrator.registerMigration("addColumn\(column.id)ToTable\(column.tableID)\(transactionCount)") { db in
            try db.alter(table: "\(column.tableID)") { t in
                var columnAdded = false
                let dataType: GRDB.Database.ColumnType
                switch column.type {
                case .table:
                    dataType = .integer
                    if let otherTableID = column.associatedTableID {
                        t.add(column: "\(column.id)", dataType)
                            .indexed()
                            .references("\(otherTableID)")
                    }
                    else {
                        print("Tried to add column \(column.name) referencing a table, but the other table's ID was nil")
                    }
                    columnAdded = true
                case .int:
                    dataType = .integer
                case .string:
                    dataType = .text
                case .bool:
                    dataType = .boolean
                case .double:
                    dataType = .double
                }
                if !columnAdded {
                    t.add(column: "\(column.id)", dataType)
                }
            }
        }
    }
    
    /// Remove the given column from the table with the ID that matches the column's tableID property
    mutating func removeColumn(_ column: DatabaseColumn) {
        defer {
            transactionCount += 1
        }
        // run SQL to remove the column
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("removeColumn\(column.id)FromTable\(column.tableID)") { db in
            try db.alter(table: "\(column.tableID)") { t in
                t.drop(column: "\(column.id)")
            }
        }
    }
    
    /// Update the given column in the table with the ID that matches the column's tableID property
    /// Updates the column by removing the existing column and adding it again; only call this method if changing the data type
    mutating func updateColumn(_ column: DatabaseColumn) {
        // run SQL to update the column
        removeColumn(column)
        addColumn(column)
    }
    
    /// Scans the SchemaDatabase and ensures all tables and columns are up to date.
    mutating func sync() throws {
        // TODO: remove all tables/purge the database? how else do we remove any tables/columns that don't exist anymore?
        if let tables = try? SchemaDatabase.shared.tablesFor(databaseID: databaseID) {
            for table in tables {
                addTable(table)
                let columns = table.columns
                for column in columns {
                    addColumn(column)
                }
            }
        }
    }
    
    private let dbWriter: any DatabaseWriter
}

extension DataDatabase {
    /// Creates an instance connected to the Database object with the given ID.
    static func discDatabaseFor(databaseID id: Database.ID) -> DataDatabase {
        do {
            // Choose folder
            let fileManager = FileManager()
            let folderURL = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                // this DB's files should be inside the databases/id directory
                .appendingPathComponent("databases", isDirectory: true)
                .appendingPathComponent("\(id)", isDirectory: true)
            
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
        // TODO: delete a file/directory (/databases/id)
    }
}

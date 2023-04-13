//
//  GRDBDatabases.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 4/10/23.
//

import Foundation
import GRDB

/// The database used to store the schemas of all the databases
struct SchemaDatabase {
    
    init (_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
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
                   t.autoIncrementedPrimaryKey("id")
                   t.column("name", .text).notNull()
               }
               
               try db.create(table: "entityType") { t in
                   t.autoIncrementedPrimaryKey("id")
                   t.column("databaseID", .integer)
                       .notNull()
                       .indexed()
                       .references("database", onDelete: .cascade)
                   t.column("name", .text)
                   t.column("shouldShow", .boolean)
               }
               
               try db.create(table: "propertyType") { t in
                   t.autoIncrementedPrimaryKey("id")
                   t.column("entityTypeID", .integer)
                       .notNull()
                       .indexed()
                       .references("entityType", onDelete: .cascade)
                   t.column("associatedEntityTypeID", .integer)
                       .indexed()
                       .references("entityType", onDelete: .setNull)
                   t.column("name", .text)
                   t.column("isPrimary", .boolean)
                   // TODO: this column is a raw value of the ValueType enum; do I need to put that here somehow, or can I just use .text?
                   t.column("type", .text)
               }
               
               try db.create(table: "entity") { t in
                   t.autoIncrementedPrimaryKey("id")
                   t.column("entityTypeID", .integer)
                       .notNull()
                       .indexed()
                       .references("entityType", onDelete: .cascade)
               }
               
               try db.create(table: "property") { t in
                   t.autoIncrementedPrimaryKey("id")
                   t.column("entityID", .integer)
                       .notNull()
                       .indexed()
                       .references("entity", onDelete: .cascade)
                   t.column("propertyTypeID", .integer)
                       .notNull()
                       .indexed()
                       .references("propertyType", onDelete: .cascade)
                   // TODO: this column is the value of an optional string that our associated propertyType tells us how to interpret
                    t.column("value", .text)
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
                .appendingPathComponent("database", isDirectory: true)

            // Support for tests: delete the database if requested
            if CommandLine.arguments.contains("-reset") {
                try? fileManager.removeItem(at: folderURL)
            }

            // Create the database folder if needed
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            // Connect to a database on disk
            // See https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections
            let dbURL = folderURL.appendingPathComponent("db.sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)

            // Create the AppDatabase
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
            // Replace this implementation with code to handle the error appropriately.
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

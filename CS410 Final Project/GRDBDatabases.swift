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
                   t.column("name", .text)
                   t.column("isPrimary", .boolean)
                   // TODO: can I make a column that holds a ValueType or do I need to make a table for that?
                   // https://github.com/groue/GRDB.swift#swift-enums seems to imply there may be an easy way of doing it, but I can't find it
                   // https://www.sqlite.org/datatype3.html
//                   t.column("type", .blob)
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
                   // TODO: column of Value or another table?
                   // t.column("value", .blob)
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

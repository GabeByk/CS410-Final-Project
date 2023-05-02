//
//  DatabaseView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import SwiftUI
import IdentifiedCollections


@MainActor
protocol DatabaseSaver: AnyObject {
    func updateDatabase(database: Database)
}

extension EditDatabasesModel: DatabaseSaver {
    func updateDatabase(database: Database) {
        self.draftDatabases[id: database.id] = database
        // we may need to update the database (e.g. the name might have changed)
        SchemaDatabase.used.updateDatabase(database)
        // we updated the database, so the parentModel doesn't need to
        parentModel?.updateDatabases(databases: draftDatabases, updateSchemaDatabase: false)
    }
}

@MainActor
final class EditDatabaseModel: ViewModel {
    // if this is weak, changes to the name of the database aren't propogated or saved
    var parentModel: DatabaseSaver?
    @Published var database: Database
    // we need to store a local copy of all the tables so the user can rename a table from this view
    @Published var tables: IdentifiedArrayOf<DatabaseTable>
        
    init(parentModel: DatabaseSaver? = nil, database: Database, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.database = database
        self.tables = database.tables
        super.init(isEditing: isEditing)
    }
    
    override func editButtonPressed() {
        // if we're exiting editing mode, update the database
        if isEditing {
            // database.tables is a computed property that returns all of the tables for this database currently stored in SchemaDatabase.shared
            for table in database.tables {
                // if we both have a table of this id, update the database to have our version
                if let updatedTable = tables[id: table.id] {
                    SchemaDatabase.used.updateTable(updatedTable)
                    // removing this means that the only values in tables after this loop ends are those that the user added to the database during this edit
                    tables.remove(updatedTable)
                }
                // if the database has it and we don't, remove it from the database
                else {
                    SchemaDatabase.used.removeTable(table)
                }
            }
            // anything left in tables at this point must have been added, so add it to the database
            for table in tables {
                SchemaDatabase.used.addTable(table)
            }
            parentModel?.updateDatabase(database: database)
        }
        // I would think that I only need to set this when entering edit mode, but for some reason not setting it when exiting edit mode causes a crash when renaming an empty table. Similarly, adding this line to cancelButtonPressed causes a crash when cancelling adding a table with a non-empty name.
        self.tables = database.tables
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        // TODO: runtime warning sometimes appears when reverting changes to tables: [SwiftUI] Publishing changes from within view updates is not allowed, this will cause undefined behavior.
        // discard the changes by fetching the data stored on disc
        if let database = SchemaDatabase.used.database(id: self.database.id) {
            self.database.name = database.name
        }
        isEditing = false
    }
    
    func addTable() {
        let table = DatabaseTable.empty(databaseID: database.id)
        tables.append(table)
    }
    
    func removeTables(at offsets: IndexSet) {
        tables.remove(atOffsets: offsets)
    }
    
    /// - returns: true if there are no unhidden tables, false otherwise
    func allTablesHidden() -> Bool {
        for table in database.tables {
            if table.shouldShow {
                return false
            }
        }
        return true
    }
}

struct EditDatabase: View {
    @ObservedObject var model: EditDatabaseModel
    
    var body: some View {
        ModelDrivenView(model: model) {
            editingView
        } nonEditingView: {
            navigatingView
        }
    }
    
    var editingView: some View {
        Form {
            Section("Database") {
                TextField("Database Name", text: $model.database.name)
            }
            Section("Tables") {
                ForEach($model.tables) { $table in
                    HStack {
                        TextField("Table Name", text: $table.name)
                        Spacer()
                        Button {
                            table.shouldShow.toggle()
                        } label: {
                            table.shouldShowImage
                        }
                    }
                }
                .onDelete(perform: removeTables)
                Button("Add Table") {
                    model.addTable()
                }
            }
        }
    }
    
    func removeTables(at offsets: IndexSet) {
        model.removeTables(at: offsets)
    }
    
    var navigatingView: some View {
        List {
            Section("Database") {
                Text(model.database.name)
            }
            Section("Tables") {
                ForEach(model.database.tables) { table in
                    if table.shouldShow {
                        NavigationLink(value: NavigationPathCase.table(EditDatabaseTableModel(parentModel: model, table: table))) {
                            Text(table.name)
                        }
                    }
                }
                if model.database.tables.count == 0 {
                    Text("Try adding some tables in the edit view!")
                }
                else if model.allTablesHidden() {
                    Text("All of your tables are hidden. You can show them again by clicking the Edit button.")
                }
            }
        }
    }
}

struct DatabaseView_Previews: PreviewProvider {
    
    struct Preview: View {
        @StateObject var app: AppModel = .mockDatabase
        
        var body: some View {
            ContentView(app: app)
        }
    }
    
    static var previews: some View {
        Preview()
    }
}

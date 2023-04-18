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
        try? SchemaDatabase.shared.updateDatabase(&draftDatabases[id: database.id]!)
        // we updated the database, so the parentModel doesn't need to
        parentModel?.updateDatabases(databases: draftDatabases, updateSchemaDatabase: false)
    }
}

@MainActor
final class EditDatabaseModel: ViewModel {
    // when parentModel isn't weak, the one passed in seems to be lost?
    #warning("EditDatabaseModel parentModel isn't weak")
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
        if isEditing {
            // the DatabaseTable constructor automatically adds any new tables and removeTables removes them, so we just need to make sure all the tables in tables are up to date in the database
            for var table in tables {
                try? SchemaDatabase.shared.updateTable(&table)
            }
            parentModel?.updateDatabase(database: database)
            if parentModel == nil {
                print("No parentModel to save changes")
            }
            // TODO: commit transaction
        }
        else {
            // TODO: start transaction
            self.tables = database.tables
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
        // TODO: cancel transaction
    }
    
    func addTable() {
        #warning("defaulting draftDatabaseID to -2 in EditDatabaseModel.addTable")
        var table = DatabaseTable.empty(databaseID: database.id ?? -2)
        // curently the constructor automatically adds it, but if we do it we would do it here
        try? SchemaDatabase.shared.addTable(&table)
        tables.append(table)
    }
    
    func removeTables(at offsets: IndexSet) {
        for offset in offsets {
            var table = tables[offset]
            try? SchemaDatabase.shared.removeTable(&table)
        }
        tables.remove(atOffsets: offsets)
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
                            DatabaseTable.shouldShowImage(shouldShow: table.shouldShow)
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

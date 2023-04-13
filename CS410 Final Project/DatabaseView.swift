//
//  DatabaseView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import SwiftUI


@MainActor
protocol DatabaseSaver: AnyObject {
    func updateDatabase(database: Database)
}

extension EditDatabasesModel: DatabaseSaver {
    func updateDatabase(database: Database) {
        self.draftDatabases[id: database.id] = database
        parentModel?.updateDatabases(databases: draftDatabases)
    }
}

@MainActor
final class EditDatabaseModel: ViewModel {
    // when parentModel isn't weak, the one passed in seems to be lost?
    #warning("EditDatabaseModel parentModel isn't weak")
    var parentModel: DatabaseSaver?
    @Published var database: Database
    @Published var draftDatabase: Database
        
    init(parentModel: DatabaseSaver? = nil, database: Database, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.database = database
        self.draftDatabase = database
        super.init(isEditing: isEditing)
    }
    
    override func editButtonPressed() {
        if isEditing {
            database = draftDatabase
            parentModel?.updateDatabase(database: draftDatabase)
            if parentModel == nil {
                print("No parentModel to save changes")
            }
        }
        else {
            draftDatabase = database
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
    }
    
    func addTable() {
        #warning("defaulting draftDatabaseID to -2 in EditDatabaseModel.addTable")
        draftDatabase.tables.append(.empty(databaseID: draftDatabase.id ?? -2))
    }
    
    func removeTables(at offsets: IndexSet) {
        draftDatabase.tables.remove(atOffsets: offsets)
    }
}

struct EditDatabase: View {
    @Environment(\.schemaDatabase) private var schemaDatabase
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
                TextField("Database Name", text: $model.draftDatabase.name)
            }
            Section("Tables") {
                ForEach($model.draftDatabase.tables) { $table in
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

//
//  DatabasesView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections
import SwiftUI

@MainActor
/// generic class used so the ModelDrivenView can encapsulate as much code as possible
class ViewModel: ObservableObject {
    
    init(isEditing: Bool = false) {
        self.isEditing = isEditing
    }
    
    // needed for ModelDrivenView
    @Published var isEditing: Bool
    
    func cancelButtonPressed() {
        print("Cancel")
    }
    
    func editButtonPressed() {
        print("Edit")
    }
}

extension ViewModel: Equatable, Hashable {
    // default implementations for automatic equatable and hashable conformance
    nonisolated static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
        return lhs === rhs
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

// helper view to automatically show edit and cancel buttons, as well as switch between views depending on model.isEditing
struct ModelDrivenView: View {
    let editingView: () -> any View
    let nonEditingView: () -> any View
    @ObservedObject var model: ViewModel
    
    init(model: ViewModel, editingView: @escaping () -> some View, nonEditingView: @escaping () -> some View) {
        self.model = model
        self.editingView = editingView
        self.nonEditingView = nonEditingView
    }
    
    var body: some View {
        VStack {
            if model.isEditing {
                AnyView(editingView())
                    .navigationBarBackButtonHidden()
            }
            else {
                AnyView(nonEditingView())
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                editButton
            }
            if model.isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
            }
        }
    }
    
    var editButton: some View {
        Button(model.isEditing ? "Done" : "Edit") {
            model.editButtonPressed()
        }
    }
    
    var cancelButton: some View {
        Button("Cancel", role: .cancel) {
            model.cancelButtonPressed()
        }
        .tint(.red)
    }
}

@MainActor
protocol DatabasesSaver: AnyObject {
    func updateDatabases(databases: IdentifiedArrayOf<Database>, updateSchemaDatabase: Bool)
}

extension AppModel: DatabasesSaver {
    func updateDatabases(databases: IdentifiedArrayOf<Database>, updateSchemaDatabase: Bool = true) {
        var draftDatabases = databases
        if updateSchemaDatabase {
            // for each database in the schema database,
            for database in self.databases {
                // if the new version also has it, update it
                if let updated = databases[id: database.id] {
                    SchemaDatabase.used.updateDatabase(updated)
                    self.databases[id: updated.id] = updated
                    // remove this database from the draft so we can know anything that remains was added
                    draftDatabases.remove(database)
                }
                // otherwise, remove it from the schema database
                else {
                    SchemaDatabase.used.removeDatabase(database)
                    self.databases.remove(database)
                }
            }
            // add everything that's new
            for database in draftDatabases {
                SchemaDatabase.used.addDatabase(database)
            }
            self.databases += draftDatabases
        }
        else {
            self.databases = databases
        }
    }
}

@MainActor
final class EditDatabasesModel: ViewModel {
    weak var parentModel: DatabasesSaver?
    @Published var draftDatabases: IdentifiedArrayOf<Database>
    
    var databases: IdentifiedArrayOf<Database> {
        SchemaDatabase.used.allDatabases()
    }
    
    init(parentModel: DatabasesSaver? = nil, isEditing: Bool = false) {
        self.parentModel = parentModel
        // initialize draftDatabases before super.init
        self.draftDatabases = []
        super.init(isEditing: isEditing)
        // give it the value it's supposed to have after, since we can't use self.databases before super.init
        self.draftDatabases = self.databases
    }
        
    override func editButtonPressed() {
        if isEditing {
            // we may have changed multiple databases, so we need to make sure the schema database is updated
            parentModel?.updateDatabases(databases: draftDatabases, updateSchemaDatabase: true)
        }
        else {
            // if we're entering edit mode, make sure we have the most up-to-date information
            draftDatabases = databases
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        // all we need to do is exit edit mode
        isEditing = false
    }
    
    func addDatabase() {
        draftDatabases.append(.empty)
    }
    
    func removeDatabases(at offsets: IndexSet) {
        draftDatabases.remove(atOffsets: offsets)
    }
}

struct EditDatabases: View {
    @ObservedObject var model: EditDatabasesModel
    
    var body: some View {
        ModelDrivenView(model: model) {
            editingView
        } nonEditingView: {
            navigatingView
        }
    }
    
    func removeDatabases(at offsets: IndexSet) {
        model.removeDatabases(at: offsets)
    }
    
    var editingView: some View {
        Form {
            Section("Databases") {
                ForEach($model.draftDatabases) { $database in
                    TextField("Database Name", text: $database.name)
                }
                .onDelete(perform: removeDatabases)
                Button("Add Database") {
                    self.model.addDatabase()
                }
            }
        }
    }
    
    var navigatingView: some View {
        List {
            Section("Databases") {
                ForEach(model.databases) { database in
                    NavigationLink(value: NavigationPathCase.database(EditDatabaseModel(parentModel: self.model, database: database))) {
                        Text(database.name)
                    }
                }
                if model.databases.count == 0 {
                    Text("Try adding a database in the edit menu!")
                }
            }
        }
    }
}

struct EditDatabases_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(app: AppModel())
    }
}

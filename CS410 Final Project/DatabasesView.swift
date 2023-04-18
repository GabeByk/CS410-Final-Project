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
    // default implementations for equatable and hashable conformance
    nonisolated static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
        return lhs === rhs
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

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
                // https://www.swiftbysundell.com/articles/opaque-return-types-in-swift/
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
    var databases: IdentifiedArrayOf<Database> { get }
}

extension AppModel: DatabasesSaver {
    func updateDatabases(databases: IdentifiedArrayOf<Database>, updateSchemaDatabase: Bool = true) {
        var draftDatabases = databases
        if updateSchemaDatabase {
            // for each database we have,
            for database in self.databases {
                // if it's still in here, update it
                if var updated = databases[id: database.id] {
                    try? SchemaDatabase.shared.updateDatabase(&updated)
                    self.databases[id: updated.id] = updated
                }
                // otherwise, remove it
                else {
                    try? SchemaDatabase.shared.removeDatabase(&self.databases[id: database.id]!)
                    self.databases.remove(database)
                }
                // remove this database from the draft so we can know anything that remains was added
                draftDatabases.remove(database)
            }
            // update everything that was added; it was added as an empty version, so we need to change it
            for var database in draftDatabases {
                try? SchemaDatabase.shared.updateDatabase(&database)
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
    weak var parentModel: (any DatabasesSaver)?
    @Published var draftDatabases: IdentifiedArrayOf<Database>
    
    var databases: IdentifiedArrayOf<Database> {
        parentModel?.databases ?? []
    }
    
    init(parentModel: DatabasesSaver? = nil, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.draftDatabases = parentModel?.databases ?? []
        super.init(isEditing: isEditing)
    }
        
    override func editButtonPressed() {
        // TODO: figure out how transactions work https://swiftpackageindex.com/groue/grdb.swift/v6.11.0/documentation/grdb/transactions
        // TODO: start a transaction when edit is pressed, commit it when done is pressed
        if isEditing {
            // we may have changed multiple databases, so we're responsible for updating the SchemaDatabase
            parentModel?.updateDatabases(databases: draftDatabases, updateSchemaDatabase: true)
        }
        else {
            draftDatabases = databases
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        // TODO: cancel/revert the transaction when cancel is pressed
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

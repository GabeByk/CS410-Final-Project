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
    
    // needed for ModelDrivenView's default implementations
    @Published var isEditing: Bool
    func cancelButtonPressed() {
        print("Cancel")
    }
    func editButtonPressed() {
        print("Edit")
    }
}

extension ViewModel: Equatable, Hashable {
    // default implementations
    nonisolated static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
        return lhs === rhs
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

@MainActor
class ModelDrivenView<ModelType: ViewModel> {
    @ObservedObject var model: ModelType
    
    init(model: ModelType) {
        self.model = model
    }
    
    @ViewBuilder var editAndCancelButtons: some View {
        HStack {
            if model.isEditing {
                Button("Cancel") {
                    self.model.cancelButtonPressed()
                }
                .tint(.red)
                .padding(.horizontal, 20)
            }
            Spacer()
            Button(model.isEditing ? "Done" : "Edit") {
                self.model.editButtonPressed()
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder var body: some View {
        VStack {
            editAndCancelButtons
            // this syntax would be great:
            // model.isEditing ? editingView : navigatingView
            if model.isEditing {
                editingView()
            }
            else {
                navigatingView()
            }
        }
    }
    
    @ViewBuilder func editingView() -> some View {
        Text("Editing")
    }
    
    @ViewBuilder func navigatingView() -> some View {
        Text("Navigating")
    }
}

@MainActor
protocol DatabasesSaver: AnyObject {
    func updateDatabases(databases: IdentifiedArrayOf<Database>)
    var databases: IdentifiedArrayOf<Database> { get }
}

@MainActor
final class EditDatabasesModel: ViewModel, DatabaseSaver {
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
        if isEditing {
            parentModel?.updateDatabases(databases: draftDatabases)
        }
        else {
            draftDatabases = databases
        }
        isEditing.toggle()
    }
    
    func updateDatabase(database: Database) {
        self.draftDatabases[id: database.id] = database
        parentModel?.updateDatabases(databases: draftDatabases)
    }
    
    override func cancelButtonPressed() {
        isEditing = false
    }
    
    func addDatabase() {
        draftDatabases.append(.empty)
    }
    
    func removeDatabases(at offsets: IndexSet) {
        draftDatabases.remove(atOffsets: offsets)
    }
}

@MainActor
// Fatal error: views must be value types (either a struct or an enum); EditDatabases is a class.
// structs can't inherit from anything but a protocol, so ModelDrivenView must be a protocol
final class EditDatabases: ModelDrivenView<EditDatabasesModel>, View {
    func editingView() -> some View {
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
    
    func navigatingView() -> some View {
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
    
    func removeDatabases(at offsets: IndexSet) {
        model.removeDatabases(at: offsets)
    }
}

struct EditDatabases_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(app: AppModel())
    }
}

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
    func updateDatabases(databases: IdentifiedArrayOf<Database>)
    var databases: IdentifiedArrayOf<Database> { get }
}

extension AppModel: DatabasesSaver {
    func updateDatabases(databases: IdentifiedArrayOf<Database>) {
        self.databases = databases
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
        if isEditing {
            parentModel?.updateDatabases(databases: draftDatabases)
        }
        else {
            draftDatabases = databases
        }
        isEditing.toggle()
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

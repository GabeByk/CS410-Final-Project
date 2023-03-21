//
//  DatabasesView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import Foundation
import IdentifiedCollections
import SwiftUI

struct DatabasesView: View {
    var databases: IdentifiedArrayOf<Database>
    
    var body: some View {
        Form {
            ForEach(databases) { table in
                Text(table.name)
            }
            if databases.count == 0 {
                Text("Try adding a database in the edit menu!")
            }
        }
    }
}

@MainActor
protocol DatabasesSaver: AnyObject {
    func updateDatabases(databases: IdentifiedArrayOf<Database>)
    var databases: IdentifiedArrayOf<Database> { get }
}

@MainActor
final class EditDatabasesModel: ObservableObject {
    weak var parentModel: DatabasesSaver?
    @Published var draftDatabases: IdentifiedArrayOf<Database>
    @Published var isEditing: Bool
    
    var databases: IdentifiedArrayOf<Database> {
        parentModel?.databases ?? []
    }
    
    init(parentModel: DatabasesSaver? = nil, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.draftDatabases = parentModel?.databases ?? []
        self.isEditing = isEditing
    }
    
    var hasChanges: Bool { databases != draftDatabases }
    
    func addDatabase(name: String) {
        draftDatabases.append(Database(name: name))
    }
    
    func editButtonPressed() {
        if isEditing {
            parentModel?.updateDatabases(databases: draftDatabases)
        }
        else {
            draftDatabases = databases
        }
        isEditing.toggle()
    }
    
    func cancelButtonPressed() {
        isEditing = false
    }
    
    func removeDatabases(at offsets: IndexSet) {
        draftDatabases.remove(atOffsets: offsets)
    }
}

struct EditDatabases: View {
    @ObservedObject var model: EditDatabasesModel
    
    var body: some View {
        VStack {
            HStack {
                if model.isEditing {
                    Button("Cancel") {
                        model.cancelButtonPressed()
                    }
                    .tint(.red)
                    .padding(.horizontal, 20)
                }
                Spacer()
                Button(model.isEditing ? "Done" : "Edit") {
                    model.editButtonPressed()
                }
                .padding(.horizontal, 20)
            }
            if model.isEditing {
                Form {
                    ForEach($model.draftDatabases) { $table in
                        TextField("Database Name", text: $table.name)
                    }
                    .onDelete(perform: removeDatabases)
                    Button("Add Database") {
                        model.addDatabase(name: "New Database")
                    }
                }
            }
            else {
                DatabasesView(databases: model.databases)
            }
            Spacer()
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

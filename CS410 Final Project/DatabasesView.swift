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
protocol ViewModel: ObservableObject, Equatable, Hashable {
    // needed for ModelDrivenView
    var isEditing: Bool { get set }
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool
    nonisolated func hash(into hasher: inout Hasher)
    func cancelButtonPressed()
    func editButtonPressed()
}

extension ViewModel {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs === rhs
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

// TODO: ask Dr. Reed how to make this work
// goal: anything that's a ModelDrivenView automatically gets editAndCancelButtons and a body, but must implement editingView and navigatingView.

//@MainActor
//protocol ModelDrivenView: View {
//    var model: any ViewModel { get }
//    @ViewBuilder var editAndCancelButtons: any View { get }
//    @ViewBuilder var editingView: any View { get }
//    @ViewBuilder var navigatingView: any View { get }
//}
//
//extension ModelDrivenView {
//    // https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/
//    var editAndCancelButtons: some View {
//        HStack {
//            if model.isEditing {
//                Button("Cancel") {
//                    model.cancelButtonPressed()
//                }
//                .tint(.red)
//                .padding(.horizontal, 20)
//            }
//            Spacer()
//            Button(model.isEditing ? "Done" : "Edit") {
//                model.editButtonPressed()
//            }
//            .padding(.horizontal, 20)
//        }
//    }
//
//    var body: some View {
//        VStack {
//            editAndCancelButtons
//            // this syntax would be great:
//            // model.isEditing ? editingView : navigatingView
//            if model.isEditing {
//                editingView
//            }
//            else {
//                navigatingView
//            }
//        }
//    }
//}

@MainActor
protocol DatabasesSaver: AnyObject {
    func updateDatabases(databases: IdentifiedArrayOf<Database>)
    var databases: IdentifiedArrayOf<Database> { get }
}

@MainActor
final class EditDatabasesModel: ViewModel, DatabaseSaver {
    weak var parentModel: (any DatabasesSaver)?
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
        
    func editButtonPressed() {
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
    
    func cancelButtonPressed() {
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
        VStack {
            editAndCancelButtons
            if model.isEditing {
                editingView
            }
            else {
                navigatingView
            }
            Spacer()
        }
    }
    
    var editAndCancelButtons: some View {
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
    }
    
    var editingView: some View {
        Form {
            Section("Databases") {
                ForEach($model.draftDatabases) { $table in
                    TextField("Database Name", text: $table.name)
                }
                .onDelete(perform: removeDatabases)
                Button("Add Database") {
                    model.addDatabase()
                }
            }
        }
    }
    
    var navigatingView: some View {
        List {
            Section("Databases") {
                ForEach(model.databases) { database in
                    NavigationLink(value: NavigationPathCase.database(EditDatabaseModel(parentModel: model, database: database))) {
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

//
//  TableView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import SwiftUI
import IdentifiedCollections

enum EditTableViewState {
    case table
    case columns
}

@MainActor
protocol DatabaseTableSaver: AnyObject {
    func updateTable(table: DatabaseTable)
    func tableFor(id: DatabaseTable.ID) -> DatabaseTable?
    var tables: IdentifiedArrayOf<DatabaseTable> { get }
}

extension EditDatabaseModel: DatabaseTableSaver {
    func updateTable(table: DatabaseTable) {
        tables[id: table.id] = table
        try? SchemaDatabase.shared.updateTable(&tables[id: table.id]!)
        parentModel?.updateDatabase(database: database)
    }
    
    func tableFor(id: DatabaseTable.ID) -> DatabaseTable? {
        return database.tables[id: id]
    }
}

@MainActor
final class EditDatabaseTableModel: ObservableObject {
    #warning("EditDatabaseTableModel parentModel isn't weak")
    var parentModel: DatabaseTableSaver?
    @Published var table: DatabaseTable
    @Published var state: EditTableViewState
    
    // TODO?: table with no columns defaults to .columns, but table with columns defaults to .table? maybe table with instances defaults to .table, so you have to switch to the table view when you add your first instance?
    init(parentModel: DatabaseTableSaver? = nil, table: DatabaseTable, state: EditTableViewState = .columns, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.table = table
        self.state = state
    }
}

extension EditDatabaseTableModel: Equatable, Hashable {
    nonisolated static func == (lhs: EditDatabaseTableModel, rhs: EditDatabaseTableModel) -> Bool {
        return lhs === rhs
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

struct EditTable: View {
    @ObservedObject var model: EditDatabaseTableModel

    var body: some View {
        switch model.state {
        case .columns:
            EditColumnsView(model: EditColumnsModel(parentModel: model, table: model.table))
        case .table:
            EditTableView(model: EditTableModel(parentModel: model, table: model.table))
        }
    }
}

struct TableView_Preview: PreviewProvider {
    struct Preview: View {
        @StateObject var app: AppModel = .mockTable
        
        var body: some View {
            ContentView(app: app)
        }
    }
    
    static var previews: some View {
        Preview()
    }
}

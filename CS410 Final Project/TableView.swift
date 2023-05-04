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
}

extension EditDatabaseModel: DatabaseTableSaver {
    func updateTable(table: DatabaseTable) {
        tables[id: table.id] = table
        SchemaDatabase.used.updateTable(table)
        parentModel?.updateDatabase(database: database)
    }
}

@MainActor
final class EditDatabaseTableModel: ObservableObject {
    weak var parentModel: DatabaseTableSaver?
    @Published var table: DatabaseTable
    @Published var state: EditTableViewState
    
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

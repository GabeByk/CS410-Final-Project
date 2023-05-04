//
//  TableView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import SwiftUI
import IdentifiedCollections

// helper enum to determine if we should show the rows or the columns
enum EditTableViewState {
    case rows
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
final class EditTableModel: ObservableObject {
    weak var parentModel: DatabaseTableSaver?
    // we only need this so we can pass it to both the EditColumnsModel and the EditRowsModel
    @Published var table: DatabaseTable
    @Published var state: EditTableViewState
    
    init(parentModel: DatabaseTableSaver? = nil, table: DatabaseTable, state: EditTableViewState = .columns, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.table = table
        self.state = state
    }
}

// an EditTableModel isn't a ViewModel, so we need to write equatable and hashable conformance
extension EditTableModel: Equatable, Hashable {
    nonisolated static func == (lhs: EditTableModel, rhs: EditTableModel) -> Bool {
        return lhs === rhs
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

struct EditTable: View {
    @ObservedObject var model: EditTableModel

    var body: some View {
        switch model.state {
        case .columns:
            EditColumnsView(model: EditColumnsModel(parentModel: model, table: model.table))
        case .rows:
            EditRows(model: EditRowsModel(parentModel: model, table: model.table))
        }
    }
}

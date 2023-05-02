//
//  RowsView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/30/23.
//

import SwiftUI
import IdentifiedCollections


protocol RowsSaver: AnyObject {
    func updateTable(_ table: DatabaseTable)
    func exitTableView()
}

extension EditDatabaseTableModel: RowsSaver {
    func exitTableView() {
        state = .columns
    }
}

final class EditTableModel: ViewModel {
    weak var parentModel: RowsSaver?
    @Published var table: DatabaseTable
    @Published var rows: IdentifiedArrayOf<DatabaseRow>
    var database: DataDatabase
    
    init(parentModel: RowsSaver? = nil, table: DatabaseTable, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.table = table
        self.database = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
        self.rows = database.rowsFor(table: table)
        super.init(isEditing: isEditing)
    }
    
    override func editButtonPressed() {
        if isEditing {
            for row in table.rows {
                if let updatedRow = rows[id: row.id] {
                    database.updateRow(updatedRow)
                    rows.remove(updatedRow)
                }
                else {
                    database.removeRow(row)
                }
            }
            for row in rows {
                database.addRow(row)
            }
            parentModel?.updateTable(table)
        }
        rows = table.rows
        if let table = SchemaDatabase.used.table(id: table.id) {
            self.table = table
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing.toggle()
        rows = table.rows
    }
    
    func viewColumnsPressed() {
        parentModel?.exitTableView()
    }
    
    func addRowPressed() {
        rows.append(.empty(tableID: table.id))
    }
    
    func removeRows(at offsets: IndexSet) {
        rows.remove(atOffsets: offsets)
    }
}

struct EditTableView: View {
    @ObservedObject var model: EditTableModel
    var body: some View {
        ModelDrivenView(model: model) {
            editingTableView
        } nonEditingView: {
            tableView
        }
    }
    
    var editingTableView: some View {
        VStack {
            List {
                Section("Table") {
                    Text("\(model.table.name)")
                }
                Section("Rows") {
                    ForEach(model.rows) { row in
                        Text("\(row.description)")
                    }
                    .onDelete(perform: removeRows)
                    
                    Button("Add Row") {
                        model.addRowPressed()
                    }
                }
            }
        }
    }
    
    func removeRows(at offsets: IndexSet) {
        model.removeRows(at: offsets)
    }
    
    var tableView: some View {
        VStack {
            List {
                Section("Table") {
                    Text("\(model.table.name)")
                    Button("View Columns") {
                        model.viewColumnsPressed()
                    }
                }
                Section("Rows") {
                    ForEach(model.rows) { row in
                        NavigationLink(value: NavigationPathCase.row(EditRowModel(parentModel: model, row: row))) {
                            Text("\(row.description)")
                        }
                    }
                    if model.rows.count == 0 {
                        Text("Try adding some rows in the edit menu!")
                    }
                }
            }
        }
    }
}

struct RowsView_Preview: PreviewProvider {
    static var previews: some View {
        TableView_Preview.previews
    }
}

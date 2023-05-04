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
    func exitRowsView()
}

extension EditTableModel: RowsSaver {
    // the EditTableModel gets its updateTable method from its conformance to ColumnsSaver, so we don't have to write it here
    func exitRowsView() {
        state = .columns
    }
}

final class EditRowsModel: ViewModel {
    weak var parentModel: RowsSaver?
    @Published var table: DatabaseTable
    @Published var rows: IdentifiedArrayOf<DatabaseRow>
    
    init(parentModel: RowsSaver? = nil, table: DatabaseTable, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.table = table
        let database = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
        self.rows = database.rowsFor(table: table)
        super.init(isEditing: isEditing)
    }
    
    override func editButtonPressed() {
        // open a connection to the disc database
        let database = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
        
        if isEditing {
            // update the disc database to reflect the changes the user made
            let rows = database.rowsFor(table: table)
            for row in rows {
                // if both the disc and our local copy have a row, make sure the database's copy is up-to-date
                if let updatedRow = self.rows[id: row.id] {
                    database.updateRow(updatedRow)
                    self.rows.remove(updatedRow)
                }
                // if the disc has it and we don't, the user must have deleted it
                else {
                    database.removeRow(row)
                }
            }
            // since everything that the disc database has was removed from self.rows, everything else is what it didn't have
            // therefore, we should add what we have left
            for row in self.rows {
                database.addRow(row)
            }
            // propogate updates to higher levels
            parentModel?.updateTable(table)
        }
        // we may have changed the database while editing, so get the newest data from the database
        self.rows = database.rowsFor(table: table)
        if let table = SchemaDatabase.used.table(id: table.id) {
            self.table = table
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
        // discard the changes the user made
        let database = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
        rows = database.rowsFor(table: table)
    }
    
    func viewColumnsPressed() {
        parentModel?.exitRowsView()
    }
    
    func addRowPressed() {
        rows.append(.empty(tableID: table.id))
    }
    
    func removeRows(at offsets: IndexSet) {
        rows.remove(atOffsets: offsets)
    }
}

struct EditRows: View {
    @ObservedObject var model: EditRowsModel
    var body: some View {
        ModelDrivenView(model: model) {
            editingView
        } nonEditingView: {
            navigatingView
        }
    }
    
    var editingView: some View {
        VStack {
            List {
                Section("Table") {
                    Text(model.table.name)
                }
                Section("Rows") {
                    ForEach(model.rows) { row in
                        Text(row.description)
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
    
    var navigatingView: some View {
        VStack {
            List {
                Section("Table") {
                    Text(model.table.name)
                    Button("View Columns") {
                        model.viewColumnsPressed()
                    }
                }
                Section("Rows") {
                    ForEach(model.rows) { row in
                        NavigationLink(value: NavigationPathCase.row(EditRowModel(parentModel: model, row: row))) {
                            Text(row.description)
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

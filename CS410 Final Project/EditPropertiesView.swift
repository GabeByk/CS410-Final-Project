//
//  EditColumnsView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/30/23.
//

import SwiftUI
import IdentifiedCollections

protocol ColumnsSaver: AnyObject {
    func updateTable(_ table: DatabaseTable)
    func exitColumnsView()
    func tableFor(id: DatabaseTable.ID) -> DatabaseTable?
    var tables: IdentifiedArrayOf<DatabaseTable> { get }
}

extension EditDatabaseTableModel: ColumnsSaver {
    func updateTable(_ table: DatabaseTable) {
        self.table = table
        parentModel?.updateTable(table: table)
    }
    
    func exitColumnsView() {
        state = .table
    }
    
    func tableFor(id: DatabaseTable.ID) -> DatabaseTable? {
        parentModel?.tableFor(id: id)
    }
    
    var tables: IdentifiedArrayOf<DatabaseTable> {
        parentModel?.tables ?? []
    }
}

final class EditColumnsModel: ViewModel {
    #warning("EditColumnsModel parentModel isn't weak")
    var parentModel: ColumnsSaver?
    @Published var table: DatabaseTable
    @Published var columns: IdentifiedArrayOf<DatabaseColumn>
    
    // TODO?: table with no columns defaults to .columns, but table with columns defaults to .table? maybe table with rows defaults to .table, so you have to switch to the table view when you add your first row?
    init(parentModel: ColumnsSaver? = nil, table: DatabaseTable, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.table = table
        self.columns = table.columns
        super.init(isEditing: isEditing)
    }
    
    func viewTablePressed() {
        parentModel?.exitColumnsView()
    }
    
    override func editButtonPressed() {
        // TODO?: what causes runtime warning "Publishing changes from within view updates is not allowed, this will cause undefined behavior."?
        // something I changed seems to have fixed it?
        if isEditing {
            for column in table.columns {
                // if we have a column that the draft doesn't, remove it
                if columns[id: column.id] == nil {
                    try? SchemaDatabase.shared.removeColumn(&columns[id: column.id]!)
                    columns.remove(column)
                }
                else {
                    try? SchemaDatabase.shared.updateColumn(&columns[id: column.id]!)
                    columns[id: column.id] = table.columns[id: column.id]!
                }
            }
            parentModel?.updateTable(table)
            // TODO: commit transaction
        }
        else {
            // TODO: start transaction
            columns = table.columns
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
        // TODO: cancel transaction
    }
    
    func addColumn() {
        #warning("defaulting tableID to -2 in EditColumnsModel.addColumn")
        var column: DatabaseColumn = .empty(tableID: table.id ?? -2)
        try? SchemaDatabase.shared.addColumn(&column)
        columns.append(column)
        table.addColumn(column)
    }
    
    func removeColumns(at offsets: IndexSet) {
        for offset in offsets {
            var column = columns[offset]
            try? SchemaDatabase.shared.removeColumn(&column)
        }
        columns.remove(atOffsets: offsets)
    }
    
}

struct EditColumnsView: View {
    @ObservedObject var model: EditColumnsModel
    
    var body: some View {
        ModelDrivenView(model: model) {
            editingColumnsView
        } nonEditingView: {
            columnsView
        }
    }
    
    var editingColumnsView: some View {
        Form {
            Section("Table") {
                HStack {
                    TextField("Table Name", text: $model.table.name)
                    Spacer()
                    Button {
                        model.table.shouldShow.toggle()
                    } label: {
                        DatabaseTable.shouldShowImage(shouldShow: model.table.shouldShow)
                    }
                }
            }
            Section("Columns") {
                ForEach($model.columns) { $column in
                    HStack {
                        TextField("Column Name", text: $column.name)
                        Spacer()
                        Button {
                            column.isPrimary.toggle()
                        } label: {
                            // TODO: have a pop-up tutorial type thing about what a primary key is, etc
                            DatabaseColumn.primaryKeyImage(isPrimary: column.isPrimary)
                        }
                        .buttonStyle(.borderless)
                        .tint(.red)
                    }
                }
                .onDelete(perform: removeColumns)
                Button("Add Column") {
                    model.addColumn()
                }
            }
        }
    }
    
    func removeColumns(at offsets: IndexSet) {
        model.removeColumns(at: offsets)
    }
    
    var columnsView: some View {
        VStack {
            List {
                Section("Table") {
                    HStack {
                        Text(model.table.name)
                        Spacer()
                        DatabaseTable.shouldShowImage(shouldShow: model.table.shouldShow)
                    }
                }
                Section("Columns") {
                    ForEach(model.table.columns) { column in
                        NavigationLink(value: NavigationPathCase.column(EditColumnModel(parentModel: model, column: column, isEditing: false))) {
                            HStack {
                                Text(column.name)
                                Spacer()
                                DatabaseColumn.primaryKeyImage(isPrimary: column.isPrimary)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    if model.table.columns.count == 0 {
                        // TODO?: don't show again?
                        Text("Try adding some columns in the edit view!")
                    }
                }
            }
            Button("View as Table") {
                model.viewTablePressed()
            }
        }
    }
}

struct EditColumnsView_Previews: PreviewProvider {
    static var previews: some View {
        TableView_Preview.previews
    }
}

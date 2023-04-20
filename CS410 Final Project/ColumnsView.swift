//
//  ColumnsView.swift
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
}

final class EditColumnsModel: ViewModel {
    #warning("EditColumnsModel parentModel isn't weak")
    var parentModel: ColumnsSaver?
    @Published var table: DatabaseTable
    @Published var columns: IdentifiedArrayOf<DatabaseColumn>
    
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
        if isEditing {
            // table.columns is the columns for this table in the database
            for column in table.columns {
                // if we both have a column with this id, update the database with the data for our version
                if let updatedColumn = columns[id: column.id] {
                    try? SchemaDatabase.shared.updateColumn(updatedColumn)
                    // remove the column from our version so we know anything left in it was added by the user
                    columns.remove(updatedColumn)
                }
                // if the database has it but we don't, it should be removed
                else {
                    try? SchemaDatabase.shared.removeColumn(column)
                }
            }
            // any columns now left in columns were added to the database, but not in the list yet
            for column in columns {
                try? SchemaDatabase.shared.addColumn(column)
            }
            parentModel?.updateTable(table)
        }
        // we need to sync our local variable with the database in either case
        columns = table.columns
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
    }
    
    func addColumn() {
        let column: DatabaseColumn = .empty(tableID: table.id)
        columns.append(column)
        // all addColumn does is propogate the added column to each row, but we would want to do this in the editButtonPressed method so it's cancellable
//        table.addColumn(column)
    }
    
    func removeColumns(at offsets: IndexSet) {
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
                            // TODO?: have a pop-up tutorial type thing about what a primary key is, etc
                            // TODO: column.primaryKeyImage?
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

struct ColumnsView_Previews: PreviewProvider {
    static var previews: some View {
        TableView_Preview.previews
    }
}

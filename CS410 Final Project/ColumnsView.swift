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
}

extension EditDatabaseTableModel: ColumnsSaver {
    func updateTable(_ table: DatabaseTable) {
        self.table = table
        parentModel?.updateTable(table: table)
    }
    
    func exitColumnsView() {
        state = .table
    }
}

final class EditColumnsModel: ViewModel {
    weak var parentModel: ColumnsSaver?
    @Published var table: DatabaseTable
    @Published var columns: IdentifiedArrayOf<DatabaseColumn>
    
    init(parentModel: ColumnsSaver? = nil, table: DatabaseTable, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.table = table
        self.columns = SchemaDatabase.used.columnsFor(tableID: table.id)
        super.init(isEditing: isEditing)
    }
    
    func viewTablePressed() {
        parentModel?.exitColumnsView()
    }
    
    override func editButtonPressed() {
        if isEditing {
            let columns = SchemaDatabase.used.columnsFor(tableID: table.id)
            // columns is the columns for this table in the database
            for column in columns {
                // if we both have a column with this id, update the database with the data for our version
                if let updatedColumn = self.columns[id: column.id] {
                    SchemaDatabase.used.updateColumn(updatedColumn)
                    // remove the column from our version so we know anything left in it was added by the user
                    self.columns.remove(updatedColumn)
                }
                // if the database has it but we don't, it should be removed
                else {
                    SchemaDatabase.used.removeColumn(column)
                }
            }
            // any columns now left in columns were added to the database, but not in the list yet
            for column in self.columns {
                SchemaDatabase.used.addColumn(column)
            }
            parentModel?.updateTable(table)
        }
        // we need to sync our local variable with the database in either case
        self.columns = SchemaDatabase.used.columnsFor(tableID: table.id)
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        if let table = SchemaDatabase.used.table(id: self.table.id) {
            self.table.name = table.name
            self.table.shouldShow = table.shouldShow
        }
        isEditing = false
    }
    
    func addColumn() {
        let column: DatabaseColumn = .empty(tableID: table.id)
        columns.append(column)
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
                        model.table.shouldShowImage
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
                            column.primaryKeyImage
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
                        model.table.shouldShowImage
                    }
                    // the button shouldn't be at the bottom of the screen
                    // https://stackoverflow.com/questions/74407838/why-am-i-getting-this-systemgesturegate-0x102210320-gesture-system-gesture
                    Button("View Rows") {
                        model.viewTablePressed()
                    }
                }
                Section("Columns") {
                    ForEach(SchemaDatabase.used.columnsFor(tableID: model.table.id)) { column in
                        NavigationLink(value: NavigationPathCase.column(EditColumnModel(parentModel: model, column: column, isEditing: false))) {
                            HStack {
                                Text(column.name)
                                Spacer()
                                column.primaryKeyImage
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    if SchemaDatabase.used.columnsFor(tableID: model.table.id).count == 0 {
                        Text("Try adding some columns in the edit view!")
                    }
                }

            }
        }
    }
}

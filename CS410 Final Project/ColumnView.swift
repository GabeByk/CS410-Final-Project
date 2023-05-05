//
//  ColumnView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/24/23.
//

import SwiftUI
import IdentifiedCollections

protocol ColumnSaver: AnyObject {
    func updateColumn(_ column: DatabaseColumn)
}

extension EditColumnsModel: ColumnSaver {
    func updateColumn(_ column: DatabaseColumn) {
        columns[id: column.id] = column
        SchemaDatabase.used.updateColumn(column)
        parentModel?.updateTable(table)
    }
}

@MainActor
final class EditColumnModel: ViewModel {

    weak var parentModel: ColumnSaver?
    @Published var column: DatabaseColumn
    @Published var draftColumn: DatabaseColumn
    
    // the variable that holds which data type the user currently has selected
    @Published var selectedType: String {
        // update draftColumn's instance variables to match the given data type each time the user selects a different data type
        didSet {
            switch selectedType {
            // selected type is Text
            case ValueType.string.rawValue:
                draftColumn.type = .string
                draftColumn.referencedTableID = nil
            // selected type is Integer
            case ValueType.int.rawValue:
                draftColumn.type = .int
                draftColumn.referencedTableID = nil
            // selected type is Decimal
            case ValueType.double.rawValue:
                draftColumn.type = .double
                draftColumn.referencedTableID = nil
            // selected type is True or False
            case ValueType.bool.rawValue:
                draftColumn.type = .bool
                draftColumn.referencedTableID = nil
            // selected type is Table
            case ValueType.table.rawValue:
                // if we can get a UUID from the selected table, say it's the table we're referencing
                if let id = DatabaseTable.ID(uuidString: selectedTable) {
                    draftColumn.type = .table
                    draftColumn.referencedTableID = id
                }
                // otherwise, say we aren't referencing any table (e.g. perhaps the user hasn't created the table they want yet)
                else {
                    draftColumn.type = .table
                    draftColumn.referencedTableID = nil
                }
            // we need a default since we're checking string equality rather than using an enum, but this should be all the values the user can choose from
            default:
                break
            }
        }
    }
    
    @Published var selectedTable: String = "None" {
        // update draftColumn's selected table every time the user changes it
        didSet {
            if let id = DatabaseTable.ID(uuidString: selectedTable) {
                draftColumn.referencedTableID = id
            }
            else {
                draftColumn.referencedTableID = nil
            }
        }
    }
    
    init(parentModel: ColumnSaver? = nil, column: DatabaseColumn, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.column = column
        self.draftColumn = column
        self.selectedType = column.type.rawValue
        super.init(isEditing: isEditing)
        
        if let table = referencedTable {
            self.selectedTable = table.id.uuidString
        }
        else {
            selectedTable = tables.first ?? "None"
        }
    }
    
    // all of the UUIDs of all tables in this database, to allow the user to pick which data type they want
    var tables: [String] {
        var ids: [String] = ["None"]
        if let table = SchemaDatabase.used.table(id: column.tableID) {
            let tables = SchemaDatabase.used.tablesFor(databaseID: table.databaseID)
            for table in tables {
                ids.append(table.id.uuidString)
            }
        }
        return ids
    }

    let types: [String] = [ValueType.string.rawValue, ValueType.int.rawValue, ValueType.double.rawValue, ValueType.bool.rawValue, ValueType.table.rawValue]
    
    // which table the column is referencing, if any
    var referencedTable: DatabaseTable? {
        switch column.type {
        case .table:
            if let id = column.referencedTableID {
                return SchemaDatabase.used.table(id: id)
            }
            else {
                return nil
            }
        default:
            return nil
        }
    }
    
    override func editButtonPressed() {
        if isEditing {
            column = draftColumn
            parentModel?.updateColumn(column)
        }
        else {
            draftColumn = column
            // default the selection to what's already selected
            selectedType = column.type.rawValue
            
            // default selectedTable to the table that the column references
            if let table = referencedTable {
                selectedTable = table.id.uuidString
            }
            else {
                selectedTable = "None"
            }
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
    }
}

struct EditColumn: View {
    @ObservedObject var model: EditColumnModel
    
    var editingView: some View {
        Form {
            Section("Column") {
                HStack {
                    TextField("Column Name", text: $model.draftColumn.name)
                    Spacer()
                    Button() {
                        model.draftColumn.isPrimary.toggle()
                    } label: {
                        model.draftColumn.primaryKeyImage
                    }
                    .tint(.red)
                }
            }
            Section("Data Type") {
                Picker("Data Type:", selection: $model.selectedType) {
                    ForEach(model.types, id: \.self) {
                        Text($0)
                    }
                }
            }
            // if the user selected a table, show an additional table picker
            // use a switch so it's easier to add cases for ints, strings, etc later
            switch model.selectedType {
            case ValueType.table.rawValue:
                Section("Table") {
                    if model.tables == [] {
                        Text("No Tables")
                    }
                    else {
                        Picker("Table:", selection: $model.selectedTable) {
                            ForEach(model.tables, id:\.self) { rowID in
                                if let id = DatabaseTable.ID(uuidString: rowID) {
                                    Text(SchemaDatabase.used.table(id: id)?.name ?? "Table not found")
                                }
                                else {
                                    Text(rowID)
                                }
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
            default:
                // the compiler complains if I put a break or just "break" here, so I put this here instead
                let _ = "break"
            }
        }
    }
    
    var navigatingView: some View {
        List {
            Section("Column") {
                HStack {
                    Text(model.column.name)
                    Spacer()
                    model.column.primaryKeyImage
                        .foregroundColor(.red)
                }
            }
            Section("Data Type") {
                Text(model.column.valueType)
            }
        }
    }
    
    var body: some View {
        ModelDrivenView(model: model) {
            editingView
        } nonEditingView: {
            navigatingView
        }
    }
}

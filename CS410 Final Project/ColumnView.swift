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
    @Published var selectedType: String {
        didSet {
            let selected = selectedType
            switch selected {
            case ValueType.string.rawValue:
                draftColumn.type = .string
                draftColumn.referencedTableID = nil
            case ValueType.int.rawValue:
                draftColumn.type = .int
                draftColumn.referencedTableID = nil
            case ValueType.double.rawValue:
                draftColumn.type = .double
                draftColumn.referencedTableID = nil
            case ValueType.bool.rawValue:
                draftColumn.type = .bool
                draftColumn.referencedTableID = nil
            case ValueType.table.rawValue:
                // https://developer.apple.com/documentation/foundation/uuid/3126814-init
                if let id = DatabaseTable.ID(uuidString: selectedTable) {
                    draftColumn.type = .table
                    draftColumn.referencedTableID = id
                }
                else {
                    draftColumn.type = .table
                    draftColumn.referencedTableID = nil
                }
            default:
                break
            }
        }
    }
    
    @Published var selectedTable: String = "None" {
        didSet {
            if let id = DatabaseTable.ID(uuidString: selectedTable) {
                draftColumn.type = .table
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
        self.types = [ValueType.string.rawValue, ValueType.int.rawValue, ValueType.double.rawValue, ValueType.bool.rawValue, ValueType.table.rawValue]
        super.init(isEditing: isEditing)
        if let table = referencedTable {
            self.selectedTable = table.id.uuidString
        }
        else {
            selectedTable = tables.first ?? "None"
        }
    }
    
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

    let types: [String]
    
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
            selectedType = column.type.rawValue
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
                // https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-picker-and-read-values-from-it
                Picker("Data Type:", selection: $model.selectedType) {
                    ForEach(model.types, id: \.self) {
                        Text($0)
                    }
                }
            }
            if model.selectedType == ValueType.table.rawValue {
                Section("Table") {
                    if model.tables == [] {
                        Text("No Tables")
                    }
                    else {
                        // TODO: have this come in on a sheet when a button is pressed so the picker is fullscreen?
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

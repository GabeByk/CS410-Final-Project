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
    func tableFor(id: DatabaseTable.ID) -> DatabaseTable?
    var tables: IdentifiedArrayOf<DatabaseTable> { get }
}

extension EditColumnsModel: ColumnSaver {
    func updateColumn(_ column: DatabaseColumn) {
        columns[id: column.id] = column
        try? SchemaDatabase.shared.updateColumn(&columns[id: column.id]!)
        parentModel?.updateTable(table)
    }
    
    func tableFor(id: DatabaseTable.ID) -> DatabaseTable? {
        return parentModel?.tableFor(id: id)
    }
    
    var tables: IdentifiedArrayOf<DatabaseTable> {
        return parentModel?.tables ?? []
    }
}

@MainActor
final class EditColumnModel: ViewModel {

    #warning("EditColumnModel parentModel isn't weak")
    var parentModel: ColumnSaver?
    @Published var column: DatabaseColumn
    @Published var draftColumn: DatabaseColumn
    @Published var selectedType: String {
        didSet {
            let selected = selectedType
            switch selected {
            case ValueType.string.rawValue:
                draftColumn.type = .string
                draftColumn.associatedTableID = nil
            case ValueType.int.rawValue:
                draftColumn.type = .int
                draftColumn.associatedTableID = nil
            case ValueType.double.rawValue:
                draftColumn.type = .double
                draftColumn.associatedTableID = nil
            case ValueType.bool.rawValue:
                draftColumn.type = .bool
                draftColumn.associatedTableID = nil
            case ValueType.table.rawValue:
                if let id = Int64(selectedTable) {
                    draftColumn.type = .table
                    draftColumn.associatedTableID = id
                }
                else {
                    draftColumn.type = .table
                    draftColumn.associatedTableID = nil
                }
            default:
                break
            }
        }
    }
    
    @Published var selectedTable: String = "None" {
        didSet {
            if let id = Int64(selectedTable) {
                draftColumn.type = .table
                draftColumn.associatedTableID = id
            }
            else {
                draftColumn.associatedTableID = nil
            }
        }
    }
    
    init(parentModel: ColumnSaver? = nil, column: DatabaseColumn, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.column = column
        self.draftColumn = column
        self.selectedType = column.valueType
        self.types = [ValueType.string.rawValue, ValueType.int.rawValue, ValueType.double.rawValue, ValueType.bool.rawValue, ValueType.table.rawValue]
        super.init(isEditing: isEditing)
        if let table = associatedTable {
            self.selectedTable = table.id == nil ? "None" : String(describing: table.id!)
        }
        else {
            selectedTable = tables.first ?? "None"
        }
    }
    
    var tables: [String] {
        let tables = parentModel?.tables ?? []
        var ids: [String] = ["None"]
        for table in tables {
            ids.append(table.id == nil ? "Uninitialized Table ID" : String(describing: table.id!))
        }
        return ids
    }

    let types: [String]
    
    var associatedTable: DatabaseTable? {
        switch column.type {
        case .table:
            if let id = column.associatedTableID {
                return parentModel?.tableFor(id: id)
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
            selectedType = column.valueType
            if let table = associatedTable {
                selectedTable = String(describing: table.id!)
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
                        DatabaseColumn.primaryKeyImage(isPrimary: model.draftColumn.isPrimary)
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
                        // TODO: picker view that you can scroll through
                        // TODO: seems to have been broken after changing IDs to be Int64s instead of Tagged<Self, UUID>s: there is one for each option, but it shows nil as the name
                        Picker("Table:", selection: $model.selectedTable) {
                            ForEach(model.tables, id:\.self) { rowID in
                                if let id = Int64(rowID) {
                                    Text(model.parentModel?.tableFor(id: id)?.name ?? "Table not found")
                                }
                                else {
                                    Text(rowID)
                                }
                            }
                        }
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
                    DatabaseColumn.primaryKeyImage(isPrimary: model.column.isPrimary)
                        .foregroundColor(.red)
                }
            }
            Section("Data Type") {
                Text(model.column.valueType == ValueType.table.rawValue ? model.associatedTable?.name ?? "Table not chosen" : model.column.valueType)
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

struct ColumnView_Preview: PreviewProvider {
    static var previews: some View {
        EditColumn(model: EditColumnModel(column: .empty(tableID: -1), isEditing: true))
    }
}

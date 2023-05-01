//
//  RowView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 4/20/23.
//

import SwiftUI
import IdentifiedCollections

protocol RowSaver: AnyObject {
    func updateRow(_ row: DatabaseRow)
}

extension EditTableModel: RowSaver {
    func updateRow(_ row: DatabaseRow) {
        rows[id: row.id] = row
    }
}

@MainActor
final class EditRowModel: ViewModel {
    #warning("EditRowModel ParentModel isn't weak")
    var parentModel: RowSaver?
    @Published var row: DatabaseRow
    @Published var values: IdentifiedArrayOf<ColumnValue>
    var rowsByDescription: [String : DatabaseRow.ID]
    
    init(parentModel: RowSaver? = nil, row: DatabaseRow, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.row = row
        self.values = []
        self.rowsByDescription = [:]
        super.init(isEditing: isEditing)
        refreshValues()
    }
    
    func refreshValues() {
        self.values = []
        self.rowsByDescription = [:]
        // iterate over the columns in the schema database instead of row.values so they appear in the same order
        for column in SchemaDatabase.used.columnsFor(tableID: row.tableID) {
            if let storedValue = row.valueFor(columnID: column.id) {
                switch storedValue {
                case .row(let referencedRowID, let referencedTableID):
                    // validValues should be an array of uuidStrings for each row in the referenced table
                    var validValues: [String] = []
                    var defaultValue: String? = nil
                    // if we were given a table ID
                    if let referencedTableID {
                        // and the table exists
                        if let schemaTable = SchemaDatabase.used.table(id: referencedTableID) {
                            // get the database on disc that matches this table
                            let database = DataDatabase.discDatabaseFor(databaseID: schemaTable.databaseID)
                            // get the rows for the table
                            let rows = database.rowsFor(table: schemaTable)
                            for row in rows {
                                // we need to give each row a unique string so we can figure out which one the user chose
                                // if it isn't already in here, just use the description based on the primary key
                                if !validValues.contains(row.description) {
                                    validValues.append(row.description)
                                    rowsByDescription[row.description] = row.id
                                }
                                // if there are multiple items with the same primary key, we need some more information
                                else {
                                    // count how many times we have a row with this data
                                    var count = 0
                                    for validValue in validValues {
                                        // if we already have something like Jane Smith (1), we want to get rid of the (1) we added, but not "Smith"
                                        if validValue == row.description || validValue.split(separator: " ").dropLast().joined(separator: " ") == row.description {
                                            count += 1
                                        }
                                    }
                                    validValues.append("\(row.description) (\(count))")
                                    rowsByDescription[validValues.last!] = row.id
                                }
                                if row.id == referencedRowID {
                                    defaultValue = validValues.last
                                }
                            }
                        }
                    }
                    // if we have no rows, tell the user there aren't any
                    if validValues.count == 0 {
                        validValues = ["No rows to choose"]
                    }
                    
                    self.values.append(ColumnValue(columnID: column.id, value: defaultValue, type: .picker(validValues)))
                case .int(let i):
                    self.values.append(ColumnValue(columnID: column.id, value: i, type: .textField))
                case .string(let s):
                    self.values.append(ColumnValue(columnID: column.id, value: s, type: .textField))
                case .bool(let b):
                    self.values.append(ColumnValue(columnID: column.id, value: b == nil ? nil : (b! ? "True" : "False"), type: .picker(["True", "False"])))
                case .double(let d):
                    self.values.append(ColumnValue(columnID: column.id, value: d, type: .textField))
                }
            }
        }
    }
    
    override func editButtonPressed() {
        if isEditing {
            if let table = SchemaDatabase.used.table(id: row.tableID) {
                let discDatabase = DataDatabase.discDatabaseFor(databaseID: table.databaseID)
                for value in values {
                    let newValue: StoredValue
                    if let column = SchemaDatabase.used.column(id: value.id) {
                        switch column.type {
                        case .int:
                            if value.isNull {
                                newValue = .int(nil)
                            }
                            else {
                                newValue = .int(Int(value.value))
                            }
                        case .string:
                            if value.isNull {
                                newValue = .string(nil)
                            }
                            else {
                                newValue = .string(value.value)
                            }
                        case .bool:
                            if value.isNull {
                                newValue = .bool(nil)
                            }
                            else {
                                // apparently Bool("True") is nil where Bool("true") is true
                                newValue = .bool(Bool(value.value.lowercased()))
                            }
                        case .double:
                            if value.isNull {
                                newValue = .double(nil)
                            }
                            else {
                                newValue = .double(Double(value.value))
                            }
                        case .table:
                            if !value.isNull {
                                let referencedRowID: DatabaseRow.ID? = rowsByDescription[value.value]
                                newValue = .row(referencedRowID: referencedRowID, referencedTableID: column.referencedTableID)
                            }
                            else {
                                newValue = .row(referencedRowID: nil, referencedTableID: column.referencedTableID)
                            }
                        }
                        row.updateValueFor(columnID: value.id, newValue: newValue)
                    }
                }
                discDatabase.updateRow(row)
            }
            parentModel?.updateRow(row)
            refreshValues()
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        refreshValues()
        isEditing.toggle()
    }
    
    func valueFor(columnID: DatabaseColumn.ID) -> ColumnValue? {
        return values[id: columnID]
    }
}

// what to use to get data from the user
enum ColumnType {
    case textField
    // the array of strings is the values to choose from in the picker
    case picker([String])
}

// reference typing so we can pass it in to the EditableColumnValueView and have it be edited
class ColumnValue: ObservableObject, Identifiable {
    // identified by which column it is
    let id: DatabaseColumn.ID
    // stores the current value that's been entered by the user
    @Published var value: String
    @Published var type: ColumnType
    @Published var isNull: Bool
    
    init(columnID: DatabaseColumn.ID, value: (any CustomStringConvertible)?, type: ColumnType) {
        self.id = columnID
        self.isNull = value == nil
        switch type {
        // default the entered value for a text field to be empty
        case .textField:
            self.value = value?.description ?? ""
        // default the chosen option for a picker to the first chosen value, or empty if there isn't a first value
        case let .picker(values):
            self.value = value?.description ?? values.first ?? ""
        }
        self.type = type
    }
}

struct ColumnValueView: View {
    @ObservedObject var columnValue: ColumnValue
    
    var column: DatabaseColumn? {
        return SchemaDatabase.used.column(id: columnValue.id)
    }
    
    var body: some View {
        Section(column?.name ?? "Unknown Column") {
            Text(columnValue.isNull ? "NULL" : columnValue.value.description)
        }
    }
}

final class OptionHolder: ObservableObject {
    let didSetAction: (String) -> ()
    @Published var option: String {
        didSet {
            didSetAction(option)
        }
    }
    init(option: String, didSetAction: @escaping (String) -> ()) {
        self.option = option
        self.didSetAction = didSetAction
    }
}

struct EditableColumnValueView: View {
    @ObservedObject var columnValue: ColumnValue
    static let nullOptions = ["No value", "Enter a value"]
    // it appears that didSet doesn't get triggered for an @State variable, but it does for an @ObservableObject's @Published properties, hence the overcomplicated solution
    @ObservedObject var nullSelector: OptionHolder
    
    init(columnValue: ColumnValue) {
        self.columnValue = columnValue
        // we need to initialize it to something so we can pass updateNullOptions as a parameter
        self.nullSelector = OptionHolder(option: "dummy value") { _ in
            print("This should be replaced")
        }
        
        // if the row doesn't have a value, default the picker to null
        let defaultOption: String
        if columnValue.isNull {
            defaultOption = EditableColumnValueView.nullOptions[0]
        }
        // otherwise, default it to the value
        else {
            defaultOption = EditableColumnValueView.nullOptions[1]
        }
        // now we can initialize it to the value we actually want
        self.nullSelector = OptionHolder(option: defaultOption, didSetAction: updateColumnValue)
    }
    
    func updateColumnValue(option: String) {        columnValue.isNull = option == EditableColumnValueView.nullOptions[0]
    }
    
    var column: DatabaseColumn? {
        return SchemaDatabase.used.column(id: columnValue.id)
    }
    
    var body: some View {
        if let column = column {
            Section("\(column.name) (\(column.valueType))") {
                Picker("Enter a value?", selection: $nullSelector.option) {
                    ForEach(EditableColumnValueView.nullOptions, id: \.self) { option in
                        Text(option)
                    }
                }
                if nullSelector.option != EditableColumnValueView.nullOptions[0] {
                    switch columnValue.type {
                    case let .picker(values):
                        // TODO: slide-in/fullscreen picker
                        Picker("Select Row UUID:", selection: $columnValue.value) {
                            ForEach(values, id: \.self) { value in
                                Text(value)
                            }
                        }
                    case .textField:
                        TextField("Enter a value", text: $columnValue.value)
                    }
                }
            }
        }
        else {
            Section("Unknown Column") {
                Text("Column \(columnValue.id.uuidString) not found")
            }
        }
    }
}

struct RowView: View {
    @ObservedObject var model: EditRowModel
    
    var editingView: some View {
        Form {
            Section("Row") {
                Text(model.row.description)
            }
            ForEach(model.values) { value in
                EditableColumnValueView(columnValue: value)
            }
        }
    }
    
    var nonEditingView: some View {
        List {
            Section("Row") {
                Text(model.row.description)
            }
            ForEach(model.values) { value in
                ColumnValueView(columnValue: value)
            }
            Section("UUID") {
                Text(model.row.id.uuidString)
            }
        }
    }
    
    var body: some View {
        ModelDrivenView(model: model) {
            editingView
        } nonEditingView: {
            nonEditingView
        }
    }
}

struct RowView_Previews: PreviewProvider {
    static var previews: some View {
        RowView(model: EditRowModel(row: .empty(tableID: DatabaseTable.mockID)))
    }
}

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

extension EditRowsModel: RowSaver {
    func updateRow(_ row: DatabaseRow) {
        rows[id: row.id] = row
    }
}

@MainActor
final class EditRowModel: ViewModel {
    weak var parentModel: RowSaver?
    @Published var row: DatabaseRow
    @Published var values: IdentifiedArrayOf<ColumnValue>
    
    init(parentModel: RowSaver? = nil, row: DatabaseRow, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.row = row
        self.values = []
        super.init(isEditing: isEditing)
        refreshValues(generatePickerOptions: isEditing)
    }
        
    func refreshValues(generatePickerOptions: Bool = true) {
        self.values = []
        // iterate over the columns in the schema database instead of row.values so they appear in the same order every time
        for column in SchemaDatabase.used.columnsFor(tableID: row.tableID) {
            if let storedValue = row.valueFor(columnID: column.id) {
                switch storedValue {
                case .row(let referencedRowID, let referencedTableID):
                    // ids should be an array of uuidStrings for each row in the referenced table
                    var ids: [String] = []
                    // labels should be an array of descriptions for each item
                    var labels: [String] = []
                    let defaultValue: String? = referencedRowID?.description
                    if generatePickerOptions {
                        // if we were given a table ID
                        if let referencedTableID {
                            // and the table exists
                            if let schemaTable = SchemaDatabase.used.table(id: referencedTableID) {
                                // get the database on disc that has this table
                                let database = UserDatabase.discDatabaseFor(databaseID: schemaTable.databaseID)
                                // get the rows for the table
                                let rows = database.rowsFor(table: schemaTable)
                                for row in rows {
                                    ids.append(row.id.uuidString)
                                    // only fetch the description once
                                    let description = row.description
                                    // we need to give each row a unique string so we can figure out which one the user chose
                                    // if it isn't already in here, just use the description based on the primary key
                                    if !labels.contains(description) {
                                        labels.append(description)
                                    }
                                    // if there are multiple items with the same primary key, we need some more information
                                    else {
                                        // count how many times we have a row with this data
                                        var count = 0
                                        for validValue in labels {
                                            // if we already have something like Jane Smith (1), we want to get rid of the (1) we added, but not "Smith"
                                            if validValue == description || validValue.split(separator: " ").dropLast().joined(separator: " ") == description {
                                                count += 1
                                            }
                                        }
                                        labels.append("\(description) (\(count))")
                                    }
                                }
                            }
                        }
                    }
                    // if we weren't given a table ID, use some default values
                    else {
                        labels = ["NULL"]
                        ids = ["NULL"]
                        if let referencedRowID, let referencedTableID {
                            ids = [referencedRowID.uuidString]
                            if let table = SchemaDatabase.used.table(id: referencedTableID) {
                                let database = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
                                labels = [database.row(rowID: referencedRowID, tableID: referencedTableID)?.description ?? "NULL"]
                            }
                        }
                    }
                    // if we have no rows, tell the user there aren't any
                    if labels.count == 0 {
                        labels = ["No rows to choose"]
                        ids = [referencedRowID?.uuidString ?? "NULL"]
                    }
                    
                    self.values.append(ColumnValue(columnID: column.id, value: defaultValue, type: .picker(values: ids, labels: labels)))
                case .int(let i):
                    self.values.append(ColumnValue(columnID: column.id, value: i, type: .textField))
                case .string(let s):
                    self.values.append(ColumnValue(columnID: column.id, value: s, type: .textEditor))
                case .bool(let b):
                    self.values.append(ColumnValue(columnID: column.id, value: b?.description.capitalized, type: .picker(values: ["True", "False"], labels: nil)))
                case .double(let d):
                    self.values.append(ColumnValue(columnID: column.id, value: d, type: .textField))
                }
            }
        }
    }
    
    override func editButtonPressed() {
        if isEditing {
            // save the changes the user made
            if let table = SchemaDatabase.used.table(id: row.tableID) {
                // get the database the user is trying to edit
                let discDatabase = UserDatabase.discDatabaseFor(databaseID: table.databaseID)
                // for each column the user might have changed
                for value in values {
                    // figure out what value we should put in the database
                    let newValue: StoredValue
                    // if the column exists, use its data type to figure out how we should do it
                    if let column = SchemaDatabase.used.column(id: value.id) {
                        switch column.type {
                        // for most, we can just convert the given data to the correct data type
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
                        // for tables, it's a little bit different
                        case .table:
                            if !value.isNull {
                                // since value.value is a uuidString, we can construct a UUID from it
                                let referencedRowID: DatabaseRow.ID? = DatabaseRow.ID(uuidString: value.value)
                                // then we can just input the appropraite UUIDs
                                newValue = .row(referencedRowID: referencedRowID, referencedTableID: column.referencedTableID)
                            }
                            else {
                                newValue = .row(referencedRowID: nil, referencedTableID: column.referencedTableID)
                            }
                        }
                        // now we just have to update the row's value with whatever value we got
                        row.updateValueFor(columnID: value.id, newValue: newValue)
                    }
                }
                // and propogate any changes to the database on disc
                discDatabase.updateRow(row)
            }
            // and propogate changes up the chain
            parentModel?.updateRow(row)
        }
        isEditing.toggle()
        // if we exited editing (isEditing is now false), we only want the currently selected options
        // if we're entering editing (isEditing is now true), we need all the data for the pickers
        refreshValues(generatePickerOptions: isEditing)
    }
    
    override func cancelButtonPressed() {
        // discard any changes the user made and exit editing mode
        refreshValues()
        isEditing = false
    }
}

// what to use to get data from the user
enum ColumnType {
    case textField
    case textEditor
    // values is what the picker will choose from, and labels is what will be shown to the user
    // if labels is nil, values will be shown directly
    case picker(values: [String], labels: [String]?)
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
        // default the chosen option for a picker to the first chosen value, or empty if there isn't a first value
        case let .picker(values, _):
            self.value = value?.description ?? values.first ?? ""
        // default the entered value for a text field to be empty
        case .textField, .textEditor:
            self.value = value?.description ?? ""
        }
        self.type = type
    }
}

extension ColumnValue: CustomStringConvertible {
    // shorthand so users can easily display the label without having to deal with labels
    var description: String {
        switch self.type {
        case let .picker(values, labels):
            if let labels {
                if let i = values.firstIndex(of: value) {
                    return labels[i]
                }
            }
            return value.description
        default:
            return value.description
        }
    }
}

struct ColumnValueView: View {
    @ObservedObject var columnValue: ColumnValue
    
    var column: DatabaseColumn? {
        return SchemaDatabase.used.column(id: columnValue.id)
    }
    
    var body: some View {
        Section(column?.name ?? "Unknown Column") {
            Text(columnValue.isNull ? "NULL" : columnValue.description)
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
    
    func updateColumnValue(option: String) {
        columnValue.isNull = option == EditableColumnValueView.nullOptions[0]
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
                    case let .picker(values, labels):
                        Picker("Choose an option:", selection: $columnValue.value) {
                            ForEach(values, id: \.self) { value in
                                if let labels {
                                    if let i = values.firstIndex(of: value) {
                                        Text(labels[i])
                                    }
                                    else {
                                        Text(value)
                                    }
                                }
                                else {
                                    Text(value)
                                }
                            }
                        }
                    case .textField:
                        TextField("Enter a value", text: $columnValue.value, axis: .vertical)
                    case .textEditor:
                        TextEditor(text: $columnValue.value)
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

struct EditRow: View {
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

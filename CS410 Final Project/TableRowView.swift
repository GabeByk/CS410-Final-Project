//
//  TableRowView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/30/23.
//

import SwiftUI


protocol TableSaver: AnyObject {
    func updateTable(_ table: DatabaseTable)
    func exitTableView()
}

extension EditDatabaseTableModel: TableSaver {
    func exitTableView() {
        state = .columns
    }
}

final class EditTableModel: ViewModel {
    var parentModel: TableSaver?
    @Published var table: DatabaseTable
    @Published var draftTable: DatabaseTable
    
    init(parentModel: TableSaver? = nil, table: DatabaseTable, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.table = table
        self.draftTable = table
        super.init(isEditing: isEditing)
    }
    
    override func editButtonPressed() {
        if isEditing {
            table = draftTable
            parentModel?.updateTable(table)
        }
        else {
            draftTable = table
        }
        isEditing.toggle()
    }
    
    func viewColumnsPressed() {
        parentModel?.exitTableView()
    }
}

struct TableView: View {
    let table: DatabaseTable
    
    // TODO?: does GRDB have an easy way to show a table?
    var body: some View {
        // https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-multi-column-lists-using-table
        // https://developer.apple.com/documentation/swiftui/table
        // TODO: might be better to use a list
        Table(of: DatabaseRow.self) {
            TableColumn("\(table.name)") { table in
                HStack {
                    Text(table.description)
                }
            }
        } rows: {
            // TODO: each row navigates to its own view that allows you to edit its fields. Looks like the DatabaseTable's view, but allows you to enter information for each column rather than allowing you to edit the columns
            ForEach(table.rows, content: TableRow.init)
        }
    }
}

struct EditTableView: View {
    #warning("EditTableModel parentModel isn't weak")
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
            TableView(table: model.draftTable)
            Button("Add Row") {
                model.draftTable.addInstance()
            }
        }
    }
    
    var tableView: some View {
        VStack {
            TableView(table: model.table)
            Button("View Columns") {
                model.viewColumnsPressed()
            }
        }
    }
}

struct TableRowView_Preview: PreviewProvider {
    static var previews: some View {
        TableView_Preview.previews
    }
}

//
//  EntityTableView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/30/23.
//

import SwiftUI


protocol TableSaver: AnyObject {
    func updateEntity(entity: EntityType)
    func exitTableView()
}

extension EditEntityModel: TableSaver {
    func exitTableView() {
        state = .properties
    }
}

final class EditTableModel: ViewModel {
    var parentModel: TableSaver?
    @Published var entity: EntityType
    @Published var draftEntity: EntityType
    
    init(parentModel: TableSaver? = nil, entity: EntityType, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.entity = entity
        self.draftEntity = entity
        super.init(isEditing: isEditing)
    }
    
    override func editButtonPressed() {
        if isEditing {
            entity = draftEntity
            parentModel?.updateEntity(entity: entity)
        }
        else {
            draftEntity = entity
        }
        isEditing.toggle()
    }
    
    func viewPropertiesPressed() {
        parentModel?.exitTableView()
    }
}

struct TableView: View {
    let entity: EntityType
    
    // TODO: ?does GRDB have an easy way to show a table?
    var body: some View {
        // https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-multi-column-lists-using-table
        // https://developer.apple.com/documentation/swiftui/table
        Table(of: Entity.self) {
            TableColumn("\(entity.name)") { entity in
                HStack {
                    Text(entity.description)
//                        ForEach(entity.values.keys, id: \.self) { key in
//                            Text("\(entity.values[key]!)")
//                        }
                }
            }
        } rows: {
            // TODO: each row navigates to an Entity's own view that allows you to edit its fields. Looks like the EntityType's view, but allows you to enter information for each property rather than allowing you to edit the properties
            ForEach(entity.instances, content: TableRow.init)
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
            TableView(entity: model.draftEntity)
            Button("Add Row") {
                model.draftEntity.addInstance()
            }
        }
    }
    
    var tableView: some View {
        VStack {
            TableView(entity: model.entity)
            Button("View Properties") {
                model.viewPropertiesPressed()
            }
        }
    }
}

struct EntityTableView_Previews: PreviewProvider {
    static var previews: some View {
        EditEntity_Previews.previews
    }
}

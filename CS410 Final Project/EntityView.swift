//
//  EntityView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import SwiftUI
import IdentifiedCollections

enum EntityViewState {
    case table
    case properties
}

@MainActor
protocol EntityTypeSaver: AnyObject {
    func updateEntity(entity: EntityType)
    func entityFor(id: EntityType.ID) -> EntityType?
    var entities: IdentifiedArrayOf<EntityType> { get }
}

extension EditDatabaseModel: EntityTypeSaver {
    func updateEntity(entity: EntityType) {
        self.database.entities[id: entity.id] = entity
        parentModel?.updateDatabase(database: database)
    }
    
    func entityFor(id: EntityType.ID) -> EntityType? {
        return database.entities[id: id]
    }
    
    var entities: IdentifiedArrayOf<EntityType> {
        database.entities
    }
}

@MainActor
final class EditEntityModel: ObservableObject {
    #warning("EditEntityModel parentModel isn't weak")
    var parentModel: EntityTypeSaver?
    @Published var entity: EntityType
    @Published var state: EntityViewState
    
    // TODO?: entity with no properties defaults to .properties, but entity with properties defaults to .table? maybe entity with instances defaults to .table, so you have to switch to the table view when you add your first instance?
    init(parentModel: EntityTypeSaver? = nil, entity: EntityType, state: EntityViewState = .properties, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.entity = entity
        self.state = state
    }
}

extension EditEntityModel: Equatable, Hashable {
    nonisolated static func == (lhs: EditEntityModel, rhs: EditEntityModel) -> Bool {
        return lhs === rhs
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

struct EditEntity: View {
    @Environment(\.schemaDatabase) private var schemaDatabase
    @ObservedObject var model: EditEntityModel

    var body: some View {
        switch model.state {
        case .properties:
            EditPropertiesView(model: EditPropertiesModel(parentModel: model, entity: model.entity))
        case .table:
            EditTableView(model: EditTableModel(parentModel: model, entity: model.entity))
        }
    }
}

struct EditEntity_Previews: PreviewProvider {
    struct Preview: View {
        @StateObject var app: AppModel = .mockEntity
        
        var body: some View {
            ContentView(app: app)
        }
    }
    
    static var previews: some View {
        Preview()
    }
}

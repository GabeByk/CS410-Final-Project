//
//  EntityView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import SwiftUI
import IdentifiedCollections

@MainActor
protocol EntitySaver: AnyObject {
    func updateEntity(entity: Entity)
    func entityFor(id: Entity.ID) -> Entity?
    var entities: IdentifiedArrayOf<Entity> { get }
}

extension EditDatabaseModel: EntitySaver {
    func updateEntity(entity: Entity) {
        self.database.entities[id: entity.id] = entity
        parentModel?.updateDatabase(database: database)
    }
    
    func entityFor(id: Entity.ID) -> Entity? {
        return database.entities[id: id]
    }
    
    var entities: IdentifiedArrayOf<Entity> {
        database.entities
    }
}

@MainActor
final class EditEntityModel: ViewModel {
    #warning("EditEntityModel parentModel isn't weak")
    var parentModel: EntitySaver?
    @Published var entity: Entity
    @Published var draftEntity: Entity
    
    init(parentModel: EntitySaver? = nil, entity: Entity, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.entity = entity
        self.draftEntity = entity
        super.init(isEditing: isEditing)
    }
    
    override func editButtonPressed() {
        // TODO: warning "Publishing changes from within view updates is not allowed, this will cause undefined behavior." when changing the entity's name
        if isEditing {
            entity = draftEntity
            parentModel?.updateEntity(entity: draftEntity)
        }
        else {
            draftEntity = entity
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
    }
    
    func addProperty() {
        draftEntity.properties.append(.empty)
    }
    
    func removeProperties(at offsets: IndexSet) {
        draftEntity.properties.remove(atOffsets: offsets)
    }
    
}



struct EditEntity: View {
    @ObservedObject var model: EditEntityModel

    var body: some View {
        ModelDrivenView(model: model) {
            editingView
        } nonEditingView: {
            navigatingView
        }
    }
    
    var editingView: some View {
        Form {
            Section("Entity") {
                TextField("Entity Name", text: $model.draftEntity.name)
            }
            Section("Properties") {
                ForEach($model.draftEntity.properties) { $property in
                    HStack {
                        TextField("Property Name", text: $property.name)
                        Spacer()
                        Button {
                            property.isPrimary.toggle()
                        } label: {
                            // TODO: have a pop-up tutorial type thing about what a primary key is, etc
                            primaryKeyImage(isPrimary: property.isPrimary)
                        }
                        .buttonStyle(.borderless)
                        .tint(.red)
                    }
                }
                .onDelete(perform: removeProperties)
                Button("Add Property") {
                    model.addProperty()
                }
            }
        }
    }
    
    func removeProperties(at offsets: IndexSet) {
        model.removeProperties(at: offsets)
    }
    
    var navigatingView: some View {
        List {
            Section("Entity") {
                Text(model.entity.name)
            }
            Section("Properties") {
                ForEach(model.entity.properties) { property in
                    NavigationLink(value: NavigationPathCase.property(EditPropertyModel(parentModel: model, property: property, isEditing: false))) {
                        HStack {
                            Text(property.name)
                            Spacer()
                            primaryKeyImage(isPrimary: property.isPrimary)
                                .foregroundColor(.red)
                        }
                    }
                }
                if model.entity.properties.count == 0 {
                    // TODO: don't show again?
                    Text("Try adding some properties in the edit view!")
                }
            }
        }
    }
}

// this should maybe be a static member of the class
func primaryKeyImage(isPrimary: Bool) -> Image {
    Image(systemName: isPrimary ? "key.fill" : "key")
}

struct EditEntity_Previews: PreviewProvider {
    static var previews: some View {
        EditEntity(model: EditEntityModel(entity: .empty))
    }
}

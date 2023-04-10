//
//  EditPropertiesView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/30/23.
//

import SwiftUI
import IdentifiedCollections

protocol PropertiesSaver: AnyObject {
    func updateEntity(entity: EntityType)
    func exitPropertiesView()
    func entityFor(id: EntityType.ID) -> EntityType?
    var entities: IdentifiedArrayOf<EntityType> { get }
}

extension EditEntityModel: PropertiesSaver {
    func updateEntity(entity: EntityType) {
        self.entity = entity
        parentModel?.updateEntity(entity: entity)
    }
    
    func exitPropertiesView() {
        state = .table
    }
    
    func entityFor(id: EntityType.ID) -> EntityType? {
        parentModel?.entityFor(id: id)
    }
    
    var entities: IdentifiedArrayOf<EntityType> {
        parentModel?.entities ?? []
    }
}

final class EditPropertiesModel: ViewModel {
    #warning("EditPropertiesModel parentModel isn't weak")
    var parentModel: PropertiesSaver?
    @Published var entity: EntityType
    @Published var draftEntity: EntityType
    
    // TODO?: entity with no properties defaults to .properties, but entity with properties defaults to .table? maybe entity with instances defaults to .table, so you have to switch to the table view when you add your first instance?
    init(parentModel: PropertiesSaver? = nil, entity: EntityType, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.entity = entity
        self.draftEntity = entity
        super.init(isEditing: isEditing)
    }
    
    func viewTablePressed() {
        parentModel?.exitPropertiesView()
    }
    
    override func editButtonPressed() {
        // TODO?: what causes runtime warning "Publishing changes from within view updates is not allowed, this will cause undefined behavior."?
        // something I changed seems to have fixed it?
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
        #warning("defaulting entityTypeID to -2 in EditPropertiesModel.addProperty")
        draftEntity.addProperty(.empty(entityTypeID: draftEntity.id ?? -2))
    }
    
    func removeProperties(at offsets: IndexSet) {
        draftEntity.removeProperties(at: offsets)
    }
    
}

struct EditPropertiesView: View {
    @ObservedObject var model: EditPropertiesModel
    
    var body: some View {
        ModelDrivenView(model: model) {
            editingPropertiesView
        } nonEditingView: {
            propertiesView
        }
    }
    
    var editingPropertiesView: some View {
        Form {
            Section("Entity") {
                HStack {
                    TextField("Entity Name", text: $model.draftEntity.name)
                    Spacer()
                    Button {
                        model.draftEntity.shouldShow.toggle()
                    } label: {
                        EntityType.shouldShowImage(shouldShow: model.draftEntity.shouldShow)
                    }
                }
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
                            PropertyType.primaryKeyImage(isPrimary: property.isPrimary)
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
    
    var propertiesView: some View {
        VStack {
            List {
                Section("Entity") {
                    HStack {
                        Text(model.entity.name)
                        Spacer()
                        EntityType.shouldShowImage(shouldShow: model.entity.shouldShow)
                    }
                }
                Section("Properties") {
                    ForEach(model.entity.properties) { property in
                        NavigationLink(value: NavigationPathCase.property(EditPropertyModel(parentModel: model, property: property, isEditing: false))) {
                            HStack {
                                Text(property.name)
                                Spacer()
                                PropertyType.primaryKeyImage(isPrimary: property.isPrimary)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    if model.entity.properties.count == 0 {
                        // TODO?: don't show again?
                        Text("Try adding some properties in the edit view!")
                    }
                }
            }
            Button("View Table") {
                model.viewTablePressed()
            }
        }
    }
}

struct EditPropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        EditEntity_Previews.previews
    }
}

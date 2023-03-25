//
//  PropertyView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/24/23.
//

import SwiftUI
import IdentifiedCollections

protocol PropertySaver: AnyObject {
    func updateProperty(_ property: Property)
    func entityFor(id: Entity.ID) -> Entity?
    var entities: IdentifiedArrayOf<Entity> { get }
}

extension EditEntityModel: PropertySaver {
    func updateProperty(_ property: Property) {
        entity.properties[id: property.id] = property
        parentModel?.updateEntity(entity: entity)
    }
    
    func entityFor(id: Entity.ID) -> Entity? {
        return parentModel?.entityFor(id: id)
    }
    
    var entities: IdentifiedArrayOf<Entity> {
        return parentModel?.entities ?? []
    }
}

@MainActor
final class EditPropertyModel: ViewModel {
    #warning("EditPropertyModel parentModel isn't weak")
    
    var parentModel: PropertySaver?
    @Published var property: Property
    @Published var draftProperty: Property
    @Published var selectedType: String {
        didSet {
            let selected = selectedType
            switch selected {
            case property.value.string:
                draftProperty.value = .string(nil)
            case property.value.int:
                draftProperty.value = .int(nil)
            case property.value.double:
                draftProperty.value = .double(nil)
            case property.value.bool:
                draftProperty.value = .bool(nil)
            case property.value.entity:
                if let id = Entity.ID(uuidString: selectedEntity) {
                    draftProperty.value = .entity(id)
                }
                else {
                    draftProperty.value = .entity(nil)
                }
            default:
                break
            }
        }
    }
    @Published var selectedEntity: String = "None" {
        didSet {
            if let id = Entity.ID(uuidString: selectedEntity) {
                draftProperty.value = .entity(id)
            }
            else {
                draftProperty.value = .entity(nil)
            }
        }
    }
    
    init(parentModel: PropertySaver? = nil, property: Property, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.property = property
        self.draftProperty = property
        self.selectedType = property.valueType
        self.types = [property.value.string, property.value.int, property.value.double, property.value.bool, property.value.entity]
        super.init(isEditing: isEditing)
        if let entity = associatedEntity {
            self.selectedEntity = String(describing: entity.id)
        }
        else {
            selectedEntity = entities.first ?? "None"
        }
    }
    
    var entities: [String] {
        let entities = parentModel?.entities ?? []
        var ids: [String] = ["None"]
        for entity in entities {
            ids.append(String(describing: entity.id))
        }
        return ids
    }

    let types: [String]
    
    var associatedEntity: Entity? {
        switch property.value {
        case .entity(let id):
            if let id {
                return parentModel?.entityFor(id: id)
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
            property = draftProperty
            parentModel?.updateProperty(property)
        }
        else {
            draftProperty = property
            selectedType = property.valueType
            if let entity = associatedEntity {
                selectedEntity = String(describing: entity.id)
            }
            else {
                selectedEntity = "None"
            }
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
    }
}

struct EditProperty: View {
    @ObservedObject var model: EditPropertyModel
    
    var editingView: some View {
        Form {
            Section("Property") {
                HStack {
                    TextField("Property Name", text: $model.draftProperty.name)
                    Spacer()
                    Button() {
                        model.draftProperty.isPrimary.toggle()
                    } label: {
                        primaryKeyImage(isPrimary: model.draftProperty.isPrimary)
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
            if model.selectedType == model.property.value.entity {
                Section("Entity") {
                    if model.entities == [] {
                        Text("No Entities")
                    }
                    else {
                        Picker("Entity:", selection: $model.selectedEntity) {
                            ForEach(model.entities, id:\.self) { entityID in
                                if let id = Entity.ID(uuidString: entityID) {
                                    // TODO: does showing the entity's name here cause "Publishing changes from within view updates is not allowed, this will cause undefined behavior." warning?
                                    Text(model.parentModel?.entityFor(id: id)?.name ?? "Entity not found")
                                }
                                else {
                                    Text(entityID)
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
            Section("Property") {
                HStack {
                    Text(model.property.name)
                    Spacer()
                    primaryKeyImage(isPrimary: model.property.isPrimary)
                        .foregroundColor(.red)
                }
            }
            Section("Data Type") {
                Text(model.property.valueType == model.property.value.entity ? model.associatedEntity?.name ?? "Entity not chosen" : model.property.valueType)
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

struct EditProperty_Previews: PreviewProvider {
    static var previews: some View {
        EditProperty(model: EditPropertyModel(property: .empty, isEditing: true))
    }
}

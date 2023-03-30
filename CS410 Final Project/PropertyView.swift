//
//  PropertyView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/24/23.
//

import SwiftUI
import IdentifiedCollections

protocol PropertyTypeSaver: AnyObject {
    func updateProperty(_ property: PropertyType)
    func entityFor(id: EntityType.ID) -> EntityType?
    var entities: IdentifiedArrayOf<EntityType> { get }
}

extension EditPropertiesModel: PropertyTypeSaver {
    func updateProperty(_ property: PropertyType) {
        entity.properties[id: property.id] = property
        parentModel?.updateEntity(entity: entity)
    }
    
    func entityFor(id: EntityType.ID) -> EntityType? {
        return parentModel?.entityFor(id: id)
    }
    
    var entities: IdentifiedArrayOf<EntityType> {
        return parentModel?.entities ?? []
    }
}

@MainActor
final class EditPropertyModel: ViewModel {
    #warning("EditPropertyModel parentModel isn't weak")
    
    var parentModel: PropertyTypeSaver?
    @Published var property: PropertyType
    @Published var draftProperty: PropertyType
    @Published var selectedType: String {
        didSet {
            let selected = selectedType
            switch selected {
            case Value.stringForString:
                draftProperty.type = .string(nil)
            case Value.stringForInt:
                draftProperty.type = .int(nil)
            case Value.stringForDouble:
                draftProperty.type = .double(nil)
            case Value.stringForBool:
                draftProperty.type = .bool(nil)
            case Value.stringForEntity:
                if let id = EntityType.ID(uuidString: selectedEntity) {
                    draftProperty.type = .entity(id)
                }
                else {
                    draftProperty.type = .entity(nil)
                }
            default:
                break
            }
        }
    }
    @Published var selectedEntity: String = "None" {
        didSet {
            if let id = EntityType.ID(uuidString: selectedEntity) {
                draftProperty.type = .entity(id)
            }
            else {
                draftProperty.type = .entity(nil)
            }
        }
    }
    
    init(parentModel: PropertyTypeSaver? = nil, property: PropertyType, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.property = property
        self.draftProperty = property
        self.selectedType = property.valueType
        self.types = [Value.stringForString, Value.stringForInt, Value.stringForDouble, Value.stringForBool, Value.stringForEntity]
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
    
    var associatedEntity: EntityType? {
        switch property.type {
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
                        PropertyType.primaryKeyImage(isPrimary: model.draftProperty.isPrimary)
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
            if model.selectedType == Value.stringForEntity {
                Section("Entity") {
                    if model.entities == [] {
                        Text("No Entities")
                    }
                    else {
                        Picker("Entity:", selection: $model.selectedEntity) {
                            ForEach(model.entities, id:\.self) { entityID in
                                if let id = EntityType.ID(uuidString: entityID) {
                                    // TODO: ?does showing the entity's name here cause "Publishing changes from within view updates is not allowed, this will cause undefined behavior." warning?
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
                    PropertyType.primaryKeyImage(isPrimary: model.property.isPrimary)
                        .foregroundColor(.red)
                }
            }
            Section("Data Type") {
                Text(model.property.valueType == Value.stringForEntity ? model.associatedEntity?.name ?? "Entity not chosen" : model.property.valueType)
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

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
            case ValueType.string.rawValue:
                draftProperty.type = .string
                draftProperty.associatedEntityTypeID = nil
            case ValueType.int.rawValue:
                draftProperty.type = .int
                draftProperty.associatedEntityTypeID = nil
            case ValueType.double.rawValue:
                draftProperty.type = .double
                draftProperty.associatedEntityTypeID = nil
            case ValueType.bool.rawValue:
                draftProperty.type = .bool
                draftProperty.associatedEntityTypeID = nil
            case ValueType.entity.rawValue:
                if let id = Int64(selectedEntity) {
                    draftProperty.type = .entity
                    draftProperty.associatedEntityTypeID = id
                }
                else {
                    draftProperty.type = .entity
                    draftProperty.associatedEntityTypeID = nil
                }
            default:
                break
            }
        }
    }
    
    @Published var selectedEntity: String = "None" {
        didSet {
            if let id = Int64(selectedEntity) {
                draftProperty.type = .entity
                draftProperty.associatedEntityTypeID = id
            }
            else {
                draftProperty.associatedEntityTypeID = nil
            }
        }
    }
    
    init(parentModel: PropertyTypeSaver? = nil, property: PropertyType, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.property = property
        self.draftProperty = property
        self.selectedType = property.valueType
        self.types = [ValueType.string.rawValue, ValueType.int.rawValue, ValueType.double.rawValue, ValueType.bool.rawValue, ValueType.entity.rawValue]
        super.init(isEditing: isEditing)
        if let entity = associatedEntity {
            self.selectedEntity = entity.id == nil ? "None" : String(describing: entity.id!)
        }
        else {
            selectedEntity = entities.first ?? "None"
        }
    }
    
    var entities: [String] {
        let entities = parentModel?.entities ?? []
        var ids: [String] = ["None"]
        for entity in entities {
            ids.append(entity.id == nil ? "Uninitialized Entity ID" : String(describing: entity.id!))
        }
        return ids
    }

    let types: [String]
    
    var associatedEntity: EntityType? {
        switch property.type {
        case .entity:
            if let id = property.associatedEntityTypeID {
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
                selectedEntity = String(describing: entity.id!)
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
    @Environment(\.schemaDatabase) private var schemaDatabase
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
            if model.selectedType == ValueType.entity.rawValue {
                Section("Entity") {
                    if model.entities == [] {
                        Text("No Entities")
                    }
                    else {
                        // TODO: picker view that you can scroll through
                        // TODO: seems to have been broken after changing IDs to be Int64s instead of Tagged<Self, UUID>s: there is one for each option, but it shows nil as the name
                        Picker("Entity:", selection: $model.selectedEntity) {
                            ForEach(model.entities, id:\.self) { entityID in
                                if let id = Int64(entityID) {
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
                Text(model.property.valueType == ValueType.entity.rawValue ? model.associatedEntity?.name ?? "Entity not chosen" : model.property.valueType)
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
        EditProperty(model: EditPropertyModel(property: .empty(entityTypeID: -1), isEditing: true))
    }
}

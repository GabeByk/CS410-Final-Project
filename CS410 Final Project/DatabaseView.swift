//
//  DatabaseView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/21/23.
//

import SwiftUI


@MainActor
protocol DatabaseSaver: AnyObject {
    func updateDatabase(database: Database)
}

extension EditDatabasesModel: DatabaseSaver {
    func updateDatabase(database: Database) {
        self.draftDatabases[id: database.id] = database
        parentModel?.updateDatabases(databases: draftDatabases)
    }
}

@MainActor
final class EditDatabaseModel: ViewModel {
    // when parentModel isn't weak, the one passed in seems to be lost?
    #warning("EditDatabaseModel parentModel isn't weak")
    var parentModel: DatabaseSaver?
    @Published var database: Database
    @Published var draftDatabase: Database
        
    init(parentModel: DatabaseSaver? = nil, database: Database, isEditing: Bool = false) {
        self.parentModel = parentModel
        self.database = database
        self.draftDatabase = database
        super.init(isEditing: isEditing)
    }
    
    override func editButtonPressed() {
        if isEditing {
            database = draftDatabase
            parentModel?.updateDatabase(database: draftDatabase)
            if parentModel == nil {
                print("No parentModel to save changes")
            }
        }
        else {
            draftDatabase = database
        }
        isEditing.toggle()
    }
    
    override func cancelButtonPressed() {
        isEditing = false
    }
    
    func addEntity() {
        draftDatabase.entities.append(.empty)
    }
    
    func removeEntities(at offsets: IndexSet) {
        draftDatabase.entities.remove(atOffsets: offsets)
    }
}

struct EditDatabase: View {
    @ObservedObject var model: EditDatabaseModel
    
    var body: some View {
        ModelDrivenView(model: model) {
            editingView
        } nonEditingView: {
            navigatingView
        }
    }
    
    var editingView: some View {
        Form {
            Section("Database") {
                TextField("Database Name", text: $model.draftDatabase.name)
            }
            Section("Entity") {
                ForEach($model.draftDatabase.entities) { $entity in
                    HStack {
                        TextField("Entity Name", text: $entity.name)
                        Spacer()
                        Button {
                            entity.shouldShow.toggle()
                        } label: {
                            EntityType.shouldShowImage(shouldShow: entity.shouldShow)
                        }
                    }
                }
                .onDelete(perform: removeEntities)
                Button("Add Entity") {
                    model.addEntity()
                }
            }
        }
    }
    
    func removeEntities(at offsets: IndexSet) {
        model.removeEntities(at: offsets)
    }
    
    var navigatingView: some View {
        List {
            Section("Database") {
                Text(model.database.name)
            }
            // TODO: weird jump when navigating from database screen to entity screen; gets reset after going out to the Databases screen and back
            // happens in the previews, but not the real app
            Section("Entities") {
                ForEach(model.database.entities) { entity in
                    if entity.shouldShow {
                        NavigationLink(value: NavigationPathCase.entity(EditEntityModel(parentModel: model, entity: entity))) {
                            Text(entity.name)
                        }
                    }
                }
                if model.database.entities.count == 0 {
                    Text("Try adding some entities in the edit view!")
                }
            }
        }
    }
}

struct DatabaseView_Previews: PreviewProvider {
    
    struct Preview: View {
        @StateObject var app: AppModel = .mockDatabase
        
        var body: some View {
            ContentView(app: app)
        }
    }
    
    static var previews: some View {
        Preview()
    }
}

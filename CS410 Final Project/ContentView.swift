//
//  ContentView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/20/23.
//

import SwiftUI
import IdentifiedCollections

struct ContentView: View {
    @ObservedObject var app: AppModel
    
    var body: some View {
        NavigationStack(path: $app.navigationPath) {
            EditDatabases(model: EditDatabasesModel(parentModel: app))
                .navigationDestination(for: NavigationPathCase.self) { navigationItem in
                    switch navigationItem {
                    case let .database(model):
                        EditDatabase(model: model)
                    case let .entity(model):
                        EditEntity(model: model)
                    case let .property(property):
                        Text(property.name)
                    }
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(app: AppModel())
    }
}

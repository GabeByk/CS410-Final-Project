//
//  ContentView.swift
//  CS410 Final Project
//
//  Created by Gabe Byk on 3/20/23.
//

import SwiftUI
import IdentifiedCollections

struct ContentView: View {
    // from https://github.com/groue/GRDB.swift/blob/master/Documentation/DemoApps/GRDBAsyncDemo/GRDBAsyncDemo/Views/AppView.swift
    @ObservedObject var app: AppModel
    
    var body: some View {
        NavigationStack(path: $app.navigationPath) {
            EditDatabases(model: EditDatabasesModel(parentModel: app))
                .navigationDestination(for: NavigationPathCase.self) { navigationItem in
                    navigateTo(item: navigationItem)
                }
        }
    }
}

func navigateTo(item: NavigationPathCase) -> some View {
    switch item {
    case let .database(model):
        return AnyView(EditDatabase(model: model))
    case let .entity(model):
        return AnyView(EditEntity(model: model))
    case let .property(model):
        return AnyView(EditProperty(model: model))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(app: AppModel())
    }
}

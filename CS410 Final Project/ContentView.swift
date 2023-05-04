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
                    navigateTo(item: navigationItem)
                }
        }
    }
}

// wrote this as a separate function so previews can use it
func navigateTo(item: NavigationPathCase) -> NavigatableView {
    switch item {
    case let .database(model):
        return .database(EditDatabase(model: model))
    case let .table(model):
        return .table(EditTable(model: model))
    case let .column(model):
        return .column(EditColumn(model: model))
    case let .row(model):
        return .row(EditRow(model: model))
    }
}

// this exists purely so navigateTo can be a separate function with a nice return type
enum NavigatableView {
    case database(EditDatabase)
    case table(EditTable)
    case column(EditColumn)
    case row(EditRow)
}

// this is so it counts as a view and people using it don't have to write this switch code every time
extension NavigatableView: View {
    var body: some View {
        switch self {
        case let .database(d):
            d
        case let .table(t):
            t
        case let .column(c):
            c
        case let .row(r):
            r
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(app: AppModel())
    }
}

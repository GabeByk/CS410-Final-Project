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
        EditDatabases(model: EditDatabasesModel(parentModel: app))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(app: AppModel())
    }
}

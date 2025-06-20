/*
 Author: Jadon Downs
 Created on: 6-10-25
 Description: Entry point for the Spot app, initializing the main SwiftUI view and environment.
*/

import CoreData
import SwiftUI

@main
struct SpotApp: App {
    @State private var shareManager = CloudManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(shareManager)
        }
    }
}


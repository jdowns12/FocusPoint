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

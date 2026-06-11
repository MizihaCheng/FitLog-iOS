import SwiftUI

@main
struct FitLogApp: App {
    @StateObject private var store = FitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

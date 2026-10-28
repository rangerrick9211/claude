import SwiftUI

@main
struct HeilmanApp: App {
    @StateObject private var store = TabStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                // Basecamp and the Family App are light-only, so the app chrome is too.
                .preferredColorScheme(.light)
        }
    }
}

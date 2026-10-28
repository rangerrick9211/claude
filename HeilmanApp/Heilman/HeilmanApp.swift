import SwiftUI

@main
struct HeilmanApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Each window gets its own tabs, because a web view can only be on screen in one window
/// (iPad can open two).
private struct RootView: View {
    @StateObject private var store = TabStore()

    var body: some View {
        ContentView()
            .environmentObject(store)
            // Basecamp and the Family App are light-only, so the app chrome is too.
            .preferredColorScheme(.light)
    }
}

import SwiftUI

@main
struct WatchLinkApp: App {
    @StateObject private var bluetooth = WatchBluetooth()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetooth)
                .tint(.mint)
                .preferredColorScheme(.dark)
        }
    }
}

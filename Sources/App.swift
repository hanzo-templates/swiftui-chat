import SwiftUI

@main
struct HanzoChatApp: App {
    // One Hanzo instance for the process, handed down the environment rather
    // than reached for through a global.
    @State private var hanzo = Hanzo()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView()
            }
            .environment(hanzo)
            .tint(.hanzo)
            .preferredColorScheme(.dark)
        }
    }
}

extension Color {
    /// One accent for the whole app. Views never hard-code a hex.
    static let hanzo = Color(red: 0.486, green: 0.361, blue: 1.0)
}

import SwiftUI

@main
struct PockitApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var web = WebModel()
    @StateObject private var state = PockitState()
    @StateObject private var skin = SkinManager()

    init() { Theme.applyUIKitAppearance() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(web)
                .environmentObject(state)
                .environmentObject(skin)
                .preferredColorScheme(.dark)
                .tint(Theme.switchPink)
                .font(Theme.text(17))
        }
    }
}

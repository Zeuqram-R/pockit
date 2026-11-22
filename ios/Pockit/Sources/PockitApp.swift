import SwiftUI

@main
struct PockitApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var web = WebModel()
    @StateObject private var state = PockitState()
    @StateObject private var skin = SkinManager()
    @StateObject private var store = PockitStore()
    @StateObject private var chats = ProjectChats()

    init() {
        Theme.applyUIKitAppearance()
        Notifier.shared.setUp()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(web)
                .environmentObject(state)
                .environmentObject(skin)
                .environmentObject(store)
                .environmentObject(chats)
                .preferredColorScheme(.dark)
                .tint(Theme.switchPink)
                .font(Theme.text(17))
        }
    }
}

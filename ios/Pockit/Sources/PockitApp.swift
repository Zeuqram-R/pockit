import SwiftUI

@main
struct PockitApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var web = WebModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(web)
                .preferredColorScheme(.dark)
                .tint(Theme.pink)
        }
    }
}

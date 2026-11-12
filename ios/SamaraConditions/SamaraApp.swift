import SwiftUI

@main
struct SamaraApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task { await model.boot() }
        }
    }
}

import SwiftUI

@main
struct SynologySyncApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .preferredColorScheme(appModel.appearance.colorScheme)
        }
    }
}

import SwiftUI

@main
struct PhoneVaultApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            MainView(model: model)
        }
    }
}

import SwiftData
import SwiftUI

@main
struct DenApp: App {
    @State private var controller = FocusController(timer: FocusTimer())

    init() {
        CountdownNotifier.shared.becomeDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(controller)
        }
        .modelContainer(for: [FocusSession.self, FocusTag.self])
    }
}

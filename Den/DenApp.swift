import SwiftData
import SwiftUI

@main
struct DenApp: App {
    @State private var timer = FocusTimer()

    init() {
        CountdownNotifier.shared.becomeDelegate()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(timer)
        }
        .modelContainer(for: FocusSession.self)
    }
}

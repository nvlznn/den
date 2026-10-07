import SwiftUI

struct SettingsView: View {
    @Environment(CommunityFocusStore.self) private var community
    @Environment(EggStore.self) private var store
    @Environment(FocusController.self) private var controller
    @AppStorage("liveActivityAppearance") private var appearance = "glass"
    @State private var displayedSeconds: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Live Activity", selection: $appearance) {
                        Text("Classic").tag("classic")
                        Text("Liquid Glass").tag("glass")
                    }
                }
                Section {
                    LabeledContent("Global Focus") {
                        if let seconds = displayedSeconds {
                            Text("\(Int(seconds / 3600).formatted()) hr")
                                .monospacedDigit()
                        } else {
                            Text("—")
                        }
                    }
                } footer: {
                    Text("Actual focus · Updates automatically")
                }
            }
            .navigationTitle("Settings")
            .onAppear { displayedSeconds = community.totalSeconds }
            .onChange(of: appearance) { _, _ in
                if let session = controller.timer.active { LiveActivityController.update(for: session) }
            }
            .alert("Purchases", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil }
            } message: { Text(store.message ?? "") }
        }
    }
}

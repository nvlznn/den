import SwiftUI

struct SettingsView: View {
    @Environment(CommunityFocusStore.self) private var community
    @Environment(EggStore.self) private var store
    @Environment(FocusController.self) private var controller
    @AppStorage("liveActivityAppearance") private var appearance = "glass"
    @Environment(\.openURL) private var openURL
    @State private var displayedSeconds: Double?

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// 目前 app 使用的語言，用該語言自己的名字顯示（例如「繁體中文」）。
    private var languageName: String {
        let id = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: id).localizedString(forIdentifier: id)?.localizedCapitalized ?? id
    }

    /// 標題靠左、值靠右、最右邊一個 ›。用具體的顏色：`.secondary` 這類樣式在 Form 的按鈕裡會被換成 tint 色（藍色）。
    private func row(_ title: LocalizedStringKey, value: Text) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.primary)
            Spacer()
            value
                .foregroundStyle(Color(.secondaryLabel))
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Live Activity", selection: $appearance) {
                        Text("Classic").tag("classic")
                        Text("Liquid Glass").tag("glass")
                    }
                    // 每個 app 的語言由系統設定管理，這裡直接帶使用者過去。
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        row("Language", value: Text(languageName))
                    }
                }
                Section {
                    LabeledContent("All Users’ Focus Time") {
                        if let seconds = displayedSeconds {
                            Text("\(Int(seconds / 3600).formatted()) hr")
                                .monospacedDigit()
                        } else {
                            Text("—")
                        }
                    }
                }
                Section {
                    LabeledContent("Version", value: appVersion)
                }
                #if DEBUG
                Section {
                    NavigationLink { PreviewMenu() } label: { Text(verbatim: "Preview") }
                }
                #endif
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

import SwiftUI

struct SettingsView: View {
    @Environment(Hanzo.self) private var hanzo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var hanzo = hanzo
        Form {
            Section("Endpoint") {
                TextField("API base", text: $hanzo.base)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Model", text: $hanzo.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                SecureField("sk-…", text: $hanzo.key)
            } header: {
                Text("API key")
            } footer: {
                Text("Held in memory only. Persist it in the Keychain before you ship.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") { dismiss() }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(Hanzo())
        .preferredColorScheme(.dark)
}

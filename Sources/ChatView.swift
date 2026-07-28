import SwiftUI

struct ChatView: View {
    @Environment(Hanzo.self) private var hanzo

    @State private var msgs: [Msg] = [
        Msg(role: "assistant",
            content: "Ask me anything. Set a Hanzo API key in Settings to talk to a real model."),
    ]
    @State private var draft = ""
    @State private var busy = false
    @State private var error: String?
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(msgs) { Bubble(msg: $0) }
                    }
                    .padding()
                }
                .onChange(of: msgs.last?.content) {
                    withAnimation { proxy.scrollTo(msgs.last?.id, anchor: .bottom) }
                }
            }

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message \(hanzo.model)", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .fontWeight(.bold)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(.circle)
                .disabled(busy || draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Hanzo Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !busy else { return }

        // Push the user turn plus an empty assistant turn, then stream into it.
        let history = msgs.dropFirst(msgs.count == 1 ? 1 : 0) + [Msg(role: "user", content: text)]
        draft = ""
        error = nil
        busy = true
        msgs = Array(history) + [Msg(role: "assistant", content: "")]

        Task {
            defer { busy = false }
            do {
                for try await chunk in hanzo.complete(Array(history)) {
                    msgs[msgs.count - 1].content += chunk
                }
            } catch {
                self.error = error.localizedDescription
                msgs = Array(history) // keep the draft the user just lost
            }
        }
    }
}

struct Bubble: View {
    let msg: Msg
    private var mine: Bool { msg.role == "user" }

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 40) }
            Text(msg.content.isEmpty ? "…" : msg.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(mine ? Color.hanzo : Color(.secondarySystemBackground))
                .foregroundStyle(mine ? .white : .primary)
                .clipShape(.rect(cornerRadius: 18))
            if !mine { Spacer(minLength: 40) }
        }
        .id(msg.id)
    }
}

#Preview {
    NavigationStack { ChatView() }
        .environment(Hanzo())
        .preferredColorScheme(.dark)
}

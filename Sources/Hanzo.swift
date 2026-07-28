import Foundation

/// The whole Hanzo integration: one streaming call to /v1/chat/completions.
///
/// Config is read at RUNTIME (Settings) rather than baked into the binary,
/// because a compiled-in key ships inside every copy of the app and `strings`
/// finds it in seconds. Ship the app, let the user bring the key.
struct Msg: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String
    var content: String

    enum CodingKeys: String, CodingKey { case role, content }
}

@MainActor
@Observable
final class Hanzo {
    var base = "https://api.hanzo.ai/v1"
    var model = "zen-omni"
    var key = ""

    enum Failure: LocalizedError {
        case noKey
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .noKey: "No API key. Open Settings and paste a Hanzo key."
            case let .http(code, body): "\(code) \(body.prefix(200))"
            }
        }
    }

    /// Streams the assistant reply token by token. Nothing here knows about views.
    func complete(_ messages: [Msg]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !key.isEmpty else { throw Failure.noKey }

                    var request = URLRequest(url: URL(string: "\(base)/chat/completions")!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONSerialization.data(withJSONObject: [
                        "model": model,
                        "stream": true,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                    ])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else { throw Failure.http(status, "") }

                    // `bytes.lines` already reassembles frames split across packets.
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        if let delta = Self.delta(payload), !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Pulls `choices[0].delta.content` out of one SSE frame, or nil for a
    /// keep-alive comment / a frame shape we do not model.
    nonisolated static func delta(_ json: String) -> String? {
        guard
            let data = json.data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let delta = choices.first?["delta"] as? [String: Any]
        else { return nil }
        return delta["content"] as? String
    }
}

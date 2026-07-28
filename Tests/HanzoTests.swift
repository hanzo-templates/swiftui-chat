import Testing
@testable import HanzoChat

/// The SSE parser is the one piece of this app that can be wrong in a way no
/// screenshot reveals, so it is `nonisolated static` precisely to be testable
/// without a network, a key, or a simulator.
@Suite struct DeltaTests {
    @Test func extractsContent() {
        let frame = #"{"choices":[{"delta":{"content":"hel"}}]}"#
        #expect(Hanzo.delta(frame) == "hel")
    }

    @Test func roleOnlyFrameHasNoContent() {
        // The first frame of an OpenAI-shaped stream carries only the role.
        #expect(Hanzo.delta(#"{"choices":[{"delta":{"role":"assistant"}}]}"#) == nil)
    }

    @Test func garbageIsNilNotACrash() {
        #expect(Hanzo.delta("") == nil)
        #expect(Hanzo.delta(": keep-alive") == nil)
        #expect(Hanzo.delta("{") == nil)
        #expect(Hanzo.delta(#"{"choices":[]}"#) == nil)
    }
}

@Suite @MainActor struct ConfigTests {
    @Test func refusesToCallWithoutAKey() async {
        let hanzo = Hanzo()
        hanzo.key = ""
        await #expect(throws: Hanzo.Failure.self) {
            for try await _ in hanzo.complete([Msg(role: "user", content: "hi")]) {}
        }
    }

    @Test func defaultsPointAtTheV1Surface() {
        let hanzo = Hanzo()
        #expect(hanzo.base == "https://api.hanzo.ai/v1")
    }
}

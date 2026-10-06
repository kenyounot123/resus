import Foundation
import Testing
@testable import ResusCore

private final class ProviderFixture: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        var status = 200
        var result: [String: Any] = ["clarifications": [], "cards": [["question": "What does ATP provide?", "answer": "Energy", "excerpt": "ATP provides energy."]]]
        if path == "/clarify" { result = ["clarifications": [["excerpt": "ATP", "question": "What does ATP mean here?"]], "cards": []] }
        if path == "/invented" { result["cards"] = [["question": "What?", "answer": "Energy", "excerpt": "Invented quote"]] }
        if path == "/blank" { result["cards"] = [["question": "What?", "answer": "  ", "excerpt": "ATP"]] }
        if path == "/mixed" { result["clarifications"] = [["excerpt": "ATP", "question": "Meaning?"]] }
        if path == "/many" { result["cards"] = Array(repeating: ["question": "What?", "answer": "Energy", "excerpt": "ATP"], count: 31) }
        if path == "/401" { status = 401 }
        if path == "/429" { status = 429 }
        if path == "/503" { status = 503 }
        let anthropic = path == "/anthropic"
        if path == "/openai" || anthropic {
            if let body = requestBody(), let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                if anthropic {
                    if request.value(forHTTPHeaderField: "x-api-key") != "test-key" || object["tools"] == nil || object["tool_choice"] == nil { status = 400 }
                } else {
                    if request.value(forHTTPHeaderField: "Authorization") != "Bearer test-key" || object["text"] == nil || object["store"] as? Bool != false { status = 400 }
                }
            } else { status = 400 }
        }
        let json = String(decoding: try! JSONSerialization.data(withJSONObject: result), as: UTF8.self)
        var envelope: [String: Any] = anthropic
            ? ["stop_reason": "tool_use", "content": [["type": "tool_use", "name": "study_material", "input": result]]]
            : ["status": "completed", "output": [["type": "message", "content": [["type": "output_text", "text": json]]]]]
        if path == "/truncated" { envelope["status"] = "incomplete" }
        if path == "/refusal" { envelope["output"] = [["type": "message", "content": [["type": "refusal", "refusal": "No"]]]] }
        let data = status == 200 ? try! JSONSerialization.data(withJSONObject: envelope) : Data("SECRET test-key raw provider failure".utf8)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    private func requestBody() -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
    override func stopLoading() {}
}

struct GeneratorTests {
    private func generator(_ path: String) -> Generator {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProviderFixture.self]
        return Generator(session: URLSession(configuration: config), endpoint: URL(string: "http://localhost\(path)")!)
    }
    private var note: Note { Note(courseID: UUID(), title: "Energy", text: "ATP provides energy.") }

    @Test(arguments: [Provider.openAI, .anthropic])
    func providerResponseBecomesDraftMaterial(provider: Provider) async throws {
        let result = try await generator(provider == .openAI ? "/openai" : "/anthropic").generate(note: note, clarifications: [], provider: provider, model: provider.defaultModel, key: "test-key")
        #expect(result == GenerationResult(clarifications: [], cards: [GeneratedCard(question: "What does ATP provide?", answer: "Energy", excerpt: "ATP provides energy.")]))
    }

    @Test func asksAboutAmbiguousShorthand() async throws {
        let result = try await generator("/clarify").generate(note: note, clarifications: [], provider: .openAI, model: "fixture", key: "test-key")
        #expect(result == GenerationResult(clarifications: [GeneratedClarification(excerpt: "ATP", question: "What does ATP mean here?")], cards: []))
    }

    @Test(arguments: ["/invented", "/blank", "/mixed", "/many", "/truncated", "/refusal"])
    func rejectsInvalidProviderMaterial(path: String) async {
        do {
            _ = try await generator(path).generate(note: note, clarifications: [], provider: .openAI, model: "fixture", key: "test-key")
            Issue.record("Invalid material was accepted for \(path)")
        } catch { #expect(error is ResusError) }
    }

    @Test func unansweredAndOmittedExcerptsCannotBecomeCards() async {
        for response in [ClarificationResponse.unanswered, .meaning("  "), .omit] {
            do {
                _ = try await generator("/openai").generate(note: note, clarifications: [Clarification(excerpt: "ATP", question: "Meaning?", response: response)], provider: .openAI, model: "fixture", key: "test-key")
                Issue.record("Unanswered or omitted source was accepted")
            } catch { #expect(error is ResusError) }
        }
    }

    @Test(arguments: [("/401", "The provider rejected this API key. Check it in Settings."), ("/429", "The provider's usage limit was reached. Wait or check your account billing."), ("/503", "The provider is temporarily unavailable. Try again later.")])
    func errorsAreUsefulAndDoNotLeakProviderBody(fixture: (String, String)) async {
        do {
            _ = try await generator(fixture.0).generate(note: note, clarifications: [], provider: .openAI, model: "fixture", key: "test-key")
            Issue.record("HTTP error was accepted")
        } catch { #expect(error.localizedDescription == fixture.1) }
    }
}

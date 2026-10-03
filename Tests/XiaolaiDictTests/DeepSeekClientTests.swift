import Foundation
import ModelKit
import Testing
import XiaolaiDictTestSupport
@testable import XiaolaiDict
@testable import XiaolaiDictCore
@testable import XiaolaiDictUI

struct DeepSeekClientTests {
    private let configuration = DeepSeekConfiguration(apiKey: "test-private-key")
    private let sense = ModelRequest.pickSense(SenseQuestion(
        sentence: "The ship's hold was full.", partOfSpeech: "noun", senses: ["grip", "cargo space"]))

    private func completion(_ content: String?, finish: String = "stop") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": finish,
            "message": ["content": content as Any? ?? NSNull()]]]])
    }

    @Test func environmentIsParsedAsDataWithoutExecutingShell() {
        #expect(DeepSeekConfiguration.parse("# comment\nexport DEEPSEEK_API_KEY='sk-test'\n")?.apiKey == "sk-test")
        #expect(DeepSeekConfiguration.parse("DEEPSEEK_API_KEY=\"sk-test\"\n")?.apiKey == "sk-test")
        #expect(DeepSeekConfiguration.parse("DEEPSEEK_API_KEY=\n") == nil)
        #expect(DeepSeekConfiguration.parse("DEEPSEEK_API_KEY=$(dangerous-command)\n") == nil)
        #expect(DeepSeekConfiguration.parse("DEEPSEEK_API_KEY=sk-test\nDEEPSEEK_API_KEY=\n") == nil)
        #expect(DeepSeekConfiguration.parse("UNRELATED=sk-test\n") == nil)
    }

    @Test func requestUsesOfficialHostAndDisablesThinking() throws {
        let request = try DeepSeekClient.request(for: sense, configuration: configuration)
        let bodyData = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: bodyData)
        let body = try #require(object as? [String: Any])
        #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-private-key")
        #expect(body["model"] as? String == "deepseek-flash")
        #expect((body["thinking"] as? [String: String])?["type"] == "disabled")
        #expect((body["response_format"] as? [String: String])?["type"] == "json_object")
        #expect(body["max_tokens"] as? Int == 64)
        #expect(body["stream"] as? Bool == false)
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages[1]["content"] == ModelPrompt.sense(SenseQuestion(
            sentence: "The ship's hold was full.", partOfSpeech: "noun", senses: ["grip", "cargo space"])))
        #expect(!String(decoding: bodyData, as: UTF8.self).contains(configuration.apiKey))
    }

    @Test func senseAnswerMustNameAnActualCandidate() throws {
        #expect(try DeepSeekClient.reply(from: completion("{\"senseNumber\":2}"), to: sense) == .sense(2))
        #expect(try DeepSeekClient.reply(from: completion("{\"senseNumber\":0}"), to: sense) == .sense(0))
        for answer in ["{\"senseNumber\":3}", "{\"senseNumber\":-1}", "{\"senseNumber\":1.5}", "{\"senseNumber\":\"2\"}"] {
            #expect(throws: (any Error).self) { try DeepSeekClient.reply(from: completion(answer), to: sense) }
        }
    }

    @Test func contextualWordRetainsGrammarAndTranslation() throws {
        let q = ModelRequest.translate(TranslationQuestion(sentence: "accepted", target: "zh-Hans",
                                                           wordContext: "The offer was accepted."))
        let content = "{\"readings\":[{\"partOfSpeech\":\"verb\",\"translation\":\"被接受\"}]}"
        #expect(try DeepSeekClient.reply(from: completion(content), to: q) == .translation("v. 被接受"))
        let bad = "{\"readings\":[{\"partOfSpeech\":\"unknown\",\"translation\":\"被接受\"}]}"
        #expect(throws: (any Error).self) { try DeepSeekClient.reply(from: completion(bad), to: q) }
    }

    @Test func contextAllowsOneReadingAndContextFreeWordsAllowThree() throws {
        let content = "{\"readings\":[{\"partOfSpeech\":\"verb\",\"translation\":\"拒绝了\"},{\"partOfSpeech\":\"adjective\",\"translation\":\"被拒绝的\"}]}"
        let q = TranslationQuestion(sentence: "refused", target: "zh-Hans", wordContext: "")
        #expect(try DeepSeekClient.reply(from: completion(content), to: .translate(q)) == .translation("v. 拒绝了\nadj. 被拒绝的"))
        let contextual = TranslationQuestion(sentence: "refused", target: "zh-Hans", wordContext: "They refused.")
        #expect(throws: (any Error).self) { try DeepSeekClient.reply(from: completion(content), to: .translate(contextual)) }
        let repeated = content.replacingOccurrences(of: "adjective", with: "verb")
        #expect(throws: (any Error).self) { try DeepSeekClient.reply(from: completion(repeated), to: .translate(q)) }
    }

    @Test func truncatedBlankAndUntranslatedAnswersAreRejected() throws {
        #expect(throws: (any Error).self) { try DeepSeekClient.reply(from: completion("{\"senseNumber\":2}", finish: "length"), to: sense) }
        #expect(throws: (any Error).self) { try DeepSeekClient.reply(from: completion(nil), to: sense) }
        #expect(throws: (any Error).self) { try DeepSeekClient.reply(from: completion("   "), to: sense) }
        let q = ModelRequest.translate(TranslationQuestion(sentence: "The offer was refused.", target: "zh-Hans"))
        #expect(throws: (any Error).self) { try DeepSeekClient.reply(from: completion("The offer was refused."), to: q) }
        #expect(try DeepSeekClient.reply(from: completion("这份提议被拒绝了。"), to: q) == .translation("这份提议被拒绝了。"))
    }

    @Test func remoteExplanationDropsPublisherProseAndBoundsCapturedText() throws {
        let q = SentenceQuestion(sentence: String(repeating: "x", count: 10_000), term: "approach",
                                 senseText: "Private dictionary definition", target: "zh-Hans")
        let request = try DeepSeekClient.request(for: .explain(q), configuration: configuration)
        let bodyData = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: bodyData)
        let body = try #require(object as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: String]])
        let prompt = try #require(messages.last?["content"])
        #expect(!prompt.contains("Private dictionary definition"))
        #expect(prompt.count < 2_000)
        #expect(prompt.contains("Chinese, Simplified"))
    }

    @Test func statusAndPrewarmNeverCallTheAPI() async {
        let requests = Recorder(0)
        let configuration = configuration
        let client = DeepSeekClient(load: { configuration }, send: { _ in
            requests.withLock { $0 += 1 }
            throw URLError(.badServerResponse)
        })
        #expect(await client.ask(.prewarm) == .prewarmed)
        _ = await client.ask(.status)
        #expect(await client.ask(.unload) == .unloading)
        #expect(requests.withLock { $0 } == 0)
    }

    @Test func serverErrorsNeverExposeResponseBodyOrCredential() async {
        let configuration = configuration
        let client = DeepSeekClient(load: { configuration }, send: { request in
            (Data("echoed secret test-private-key".utf8), HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
        })
        #expect(await client.ask(sense) == .failure(.generationFailed("DeepSeek authentication failed. Check the API key.")))
    }

    @Test func missingCredentialDoesNotCallAnyTransport() async {
        let requests = Recorder(0)
        let client = DeepSeekClient(load: { nil }, send: { _ in
            requests.withLock { $0 += 1 }
            throw URLError(.badServerResponse)
        })
        #expect(!client.isConfigured)
        _ = await client.ask(sense)
        #expect(requests.withLock { $0 } == 0)
    }

    @Test func missingOrFailedAPIRequestsCannotFallBackToQwen() async {
        let localConnections = Recorder(0)
        let local = ModelClient(connect: { _ in
            localConnections.withLock { $0 += 1 }
            throw URLError(.cannotConnectToHost)
        }, servicePresence: { .gone })
        let scratch = TemporaryDirectory(named: "xiaolaidict-deepseek")
        let configuration = configuration
        let loaders: [DeepSeekClient.Load] = [{ nil }, { configuration }]
        for load in loaders {
            let cloud = DeepSeekClient(load: load, send: { _ in throw URLError(.notConnectedToInternet) })
            let access = LocalModelAccess(client: local, store: ModelStore(root: scratch.url), deepSeek: cloud)
            _ = await access.ask(sense)
            await access.prewarm()
        }
        #expect(localConnections.withLock { $0 } == 0)
    }

    @Test @MainActor func cloudCoordinatorCannotDownloadOrPrewarmQwen() async {
        let requests = Recorder(0)
        let configuration = configuration
        let cloud = DeepSeekClient(load: { configuration }, send: { _ in
            requests.withLock { $0 += 1 }
            throw URLError(.badServerResponse)
        })
        let coordinator = LocalModelCoordinator(deepSeek: cloud)
        #expect(coordinator.choice.state == .api(configured: true))
        #expect(coordinator.choice.offered.isEmpty)
        #expect(!coordinator.choice.canDownload)
        #expect(!coordinator.translationActions.canDownloadModel)
        #expect(coordinator.translationActions.canTranslateWords)
        coordinator.choice.download(.standard)
        coordinator.translationActions.downloadModel()
        coordinator.refresh()
        await coordinator.prewarm()
        #expect(coordinator.pruning == nil)
        #expect(requests.withLock { $0 } == 0)
    }

    @Test func cloudAnswersAreLabelledAsDeepSeekAndRenderedAsWordGlosses() async throws {
        let q = TranslationQuestion(sentence: "hold", target: "zh-Hans", wordContext: "The ship's hold was full.")
        let translator = SentenceTranslator(local: { _ in .translation("n. 货舱") }, apple: { _, _, _ in .failed },
                                            language: { _ in "en" }, modelEngine: .deepSeek)
        let result = await translator.translate(q)
        #expect(result == .translated("n. 货舱", by: .deepSeek))
        let gloss = try #require(WordLookupTranslation(result, question: q))
        #expect(gloss.gloss.meanings.map(\.partOfSpeech) == [.noun])
    }

    #if HUIDICT_LOCAL_BUILD
    @Test func huiDictDefaultClientCannotStartTheLocalService() async {
        #expect(await ModelClient().ask(.prewarm) == nil)
        #expect(await ModelClient().ask(sense) == nil)
    }
    #endif
}

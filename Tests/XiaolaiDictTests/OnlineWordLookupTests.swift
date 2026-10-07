import AppKit
import DictionaryModel
import Foundation
import ModelKit
import SwiftUI
import Testing
import XiaolaiDictCore
@testable import XiaolaiDict
@testable import XiaolaiDictUI

private actor DelayedWordTranslation {
    private var pending: CheckedContinuation<TranslationOutcome, Never>?
    private var ready: CheckedContinuation<Void, Never>?
    private(set) var calls = 0

    func translate(_ question: TranslationQuestion) async -> TranslationOutcome {
        calls += 1
        return await withCheckedContinuation { continuation in
            pending = continuation
            ready?.resume()
            ready = nil
        }
    }

    func waitForRequest() async {
        if pending == nil { await withCheckedContinuation { ready = $0 } }
    }

    func finish(_ outcome: TranslationOutcome) {
        pending?.resume(returning: outcome)
        pending = nil
    }
}

@MainActor
struct OnlineWordLookupTests {
    private var question: TranslationQuestion {
        TranslationQuestion(sentence: "Superpersuasion", target: "zh-Hans", wordContext: "")
    }

    @Test func preparationNeverStartsARequestAndDuplicateClicksShareOneAttempt() async {
        let lookup = OnlineWordLookup(), provider = DelayedWordTranslation()
        lookup.reset(for: question)
        #expect(lookup.status(for: question) == .ready)
        #expect(await provider.calls == 0)
        let first = lookup.start(question, translate: provider.translate)
        let second = lookup.start(question, translate: provider.translate)
        #expect(lookup.status(for: question) == .loading)
        await provider.waitForRequest()
        #expect(await provider.calls == 1)
        await provider.finish(.translated("n. 超强说服力", by: .deepSeek))
        await first.value
        await second.value
        guard case .translated(let answer) = lookup.status(for: question) else {
            Issue.record("The clicked request must display its validated answer")
            return
        }
        #expect(answer.gloss.meanings.first?.translation == "超强说服力")
    }

    @Test func failureRequiresAnotherClickAndThenAllowsRecovery() async {
        let lookup = OnlineWordLookup()
        await lookup.start(question) { _ in .unavailable }.value
        #expect(lookup.status(for: question) == .unavailable)
        // Redrawing or expanding the same question preserves the failure, without retrying.
        lookup.reset(for: question)
        #expect(lookup.status(for: question) == .unavailable)
        await lookup.start(question) { _ in .translated("n. 超强说服力", by: .deepSeek) }.value
        if case .translated = lookup.status(for: question) {} else {
            Issue.record("An explicit retry must be able to recover")
        }
    }

    @Test func aClosedCardRejectsEvenAnUncooperativeLateAnswer() async {
        let lookup = OnlineWordLookup(), provider = DelayedWordTranslation()
        let work = lookup.start(question, translate: provider.translate)
        await provider.waitForRequest()
        lookup.cancel()
        await provider.finish(.translated("n. 超强说服力", by: .deepSeek))
        await work.value
        #expect(lookup.status(for: question) == .ready)
    }

    @Test func changingWordContextOrLanguageDiscardsThePreviousAnswer() async {
        let changes = [
            TranslationQuestion(sentence: "Codemode", target: "zh-Hans", wordContext: ""),
            TranslationQuestion(sentence: "Superpersuasion", target: "zh-Hans", wordContext: "The book explores superpersuasion."),
            TranslationQuestion(sentence: "Superpersuasion", target: "ja", wordContext: ""),
        ]
        for changed in changes {
            let lookup = OnlineWordLookup(), provider = DelayedWordTranslation()
            let old = lookup.start(question, translate: provider.translate)
            await provider.waitForRequest()
            lookup.reset(for: changed)
            #expect(lookup.status(for: changed) == .ready)
            await provider.finish(.translated("n. 超强说服力", by: .deepSeek))
            await old.value
            #expect(lookup.status(for: changed) == .ready)
            #expect(lookup.status(for: question) == .ready)
        }
    }

    @Test func invalidAnswersDoNotBecomeOnlineTranslations() async {
        let lookup = OnlineWordLookup()
        await lookup.start(question) { _ in .translated("Superpersuasion", by: .deepSeek) }.value
        #expect(lookup.status(for: question) == .unavailable)
    }

    @Test func missingEntryQuestionsRetainExactSpellingAndOptionalContext() throws {
        for term in ["Superpersuasion", "Codemode"] {
            for sentence in [nil, "This feature is called \(term)."] as [String?] {
                let presentation = LookupPresentation(
                    request: 1, term: term, lemma: Lemma(text: term.lowercased(), basis: .surface),
                    source: nil, capture: .accessibility(.accessibilityTextRange, context: .complete),
                    sentence: sentence, outcome: .notFound(serviceFailure: nil))
                let content = LookupPanelContent(presentation: presentation)
                #if HUIDICT_LOCAL_BUILD
                let question = try #require(content.onlineWordTranslationQuestion)
                #expect(question.sentence == term)
                #expect(question.wordContext == (sentence ?? ""))
                #expect(question.met == nil)
                #else
                #expect(content.onlineWordTranslationQuestion == nil)
                #endif
            }
        }
    }

    @Test func missingEntryFallbackDoesNotRunWhileTheDictionaryIsLoading() {
        let presentation = LookupPresentation(
            request: 1, term: "Codemode", lemma: Lemma(text: "codemode", basis: .surface),
            source: nil, capture: .accessibility(.accessibilityTextRange, context: .complete),
            sentence: nil, outcome: nil)
        #expect(LookupPanelContent(presentation: presentation).onlineWordTranslationQuestion == nil)
    }

    @Test func missingEntryControlsAndResultsFitAtBothTextSizes() async throws {
        let card = LookupCard(term: "Superpersuasion", lemma: "superpersuasion", heading: "Superpersuasion",
                              partOfSpeech: nil, pronunciation: nil, answer: .absent,
                              sentence: nil, alternatives: [])
        for size in [TextSize.standard, .large] {
            let scale = Scale(size)
            for translated in [false, true] {
                let lookup = OnlineWordLookup()
                if translated {
                    await lookup.start(question) { _ in .translated("n. 超强说服力", by: .deepSeek) }.value
                }
                let view = NSHostingView(rootView: CompactLookupCardView(
                    card: card, onlineLookup: lookup, onlineQuestion: question, onMore: {})
                    .environment(\.scale, scale)
                    .environment(\.colorScheme, .light)
                    .background(.white)
                    .frame(width: scale.space.lookupWidth))
                view.layoutSubtreeIfNeeded()
                let wanted = view.fittingSize
                #expect(wanted.width == scale.space.lookupWidth)
                #expect(wanted.height > 0 && wanted.height <= scale.space.cardMaxHeight)
                if let directory = ProcessInfo.processInfo.environment["HUIDICT_TRANSLATION_RENDER_DIR"] {
                    view.frame.size = wanted
                    view.layoutSubtreeIfNeeded()
                    let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    let png = try #require(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: URL(fileURLWithPath: directory)
                        .appendingPathComponent("online-\(size.rawValue)-\(translated ? "result" : "ready").png"))
                }
            }
        }
    }
}

/// Opt-in live verification uses the app's private runtime configuration; normal tests never call the API.
@MainActor
struct OnlineWordLookupLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["HUIDICT_ONLINE_LIVE_TEST"] == "1"),
          arguments: ["Superpersuasion", "Codemode"])
    func missingWordsTranslateThroughTheExistingDeepSeekProvider(_ term: String) async throws {
        let models = LocalModelAccess(client: ModelClient(), store: .standard(), deepSeek: DeepSeekClient())
        let question = TranslationQuestion(sentence: term, target: "zh-Hans", wordContext: "")
        let lookup = OnlineWordLookup()
        await lookup.start(question, translate: models.translator.translate).value
        guard case .translated(let answer) = lookup.status(for: question) else {
            Issue.record("DeepSeek did not return a validated translation for \(term)")
            return
        }
        #expect(!answer.gloss.meanings.isEmpty)
        print("Online lookup verified: \(term) → \(answer.gloss.text)")
    }
}

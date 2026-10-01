import AppKit
import Foundation
import ModelKit
import SwiftUI
import Testing
import XiaolaiDictCore
@testable import XiaolaiDictUI

struct WordLookupTranslationTests {
    private func card(term: String = "refused", base: String = "refuse", part: String = "verb",
                      sentence: String? = "The application was refused.",
                      standing: SenseStanding = .proposed) -> LookupCard {
        let sense = SensePresentation(key: "sense", ordinal: 1, partOfSpeech: part, label: "拒绝",
                                      keyKind: .publisher, standing: standing, metBefore: false)
        return LookupCard(term: term, lemma: base, heading: base, partOfSpeech: part,
                          pronunciation: nil, answer: .sense(sense), sentence: sentence, alternatives: [])
    }

    @Test func aWordTranslationUsesTheSurfaceAndContextWithoutForcingAnUnconfirmedSense() throws {
        let question = try #require(TranslationQuestion.word(card(), target: "zh-Hans"))
        #expect(question.sentence == "refused")
        #expect(question.wordContext == "The application was refused.")
        #expect(question.met == nil)
        let confirmed = try #require(TranslationQuestion.word(card(standing: .confirmed(.reader)), target: "zh-Hans"))
        #expect(confirmed.met?.sense == "拒绝")
    }

    @Test func anIsolatedWordDoesNotInventSurroundingContext() throws {
        let question = try #require(TranslationQuestion.word(card(sentence: nil), target: "zh-Hans"))
        #expect(question.wordContext == "")
    }

    @Test func aTranslationCannotAppearUnderAnotherWordOrSentence() throws {
        let original = try #require(TranslationQuestion.word(card(), target: "zh-Hans"))
        let translated = try #require(WordLookupTranslation(.translated("被拒绝", by: .localModel), question: original))
        #expect(translated.text(for: original) == "被拒绝")
        #expect(translated.text(for: TranslationQuestion.word(card(sentence: "They refused to sign."), target: "zh-Hans")) == nil)
        #expect(translated.text(for: TranslationQuestion.word(card(term: "accepted", base: "accept"), target: "zh-Hans")) == nil)
    }

    @Test func anUnavailableOrUnboundedAnswerKeepsTheDictionaryPreview() throws {
        let question = try #require(TranslationQuestion.word(card(), target: "zh-Hans"))
        #expect(WordLookupTranslation(.unavailable, question: question) == nil)
        #expect(WordLookupTranslation(.translated("被拒绝", by: .appleTranslation), question: question) == nil)
        #expect(WordLookupTranslation(.translated(String(repeating: "字", count: 81), by: .localModel), question: question) == nil)
    }

    @Test func theCardExplainsRegularFormsWithoutInventingAnAdjectiveSense() {
        #expect(EnglishLookupForm.description(of: card()) == "Past tense / past participle of refuse")
        #expect(EnglishLookupForm.description(of: card(term: "continues", base: "continue")) == "Third-person singular of continue")
        #expect(EnglishLookupForm.description(of: card(term: "refusing")) == "-ing form of refuse")
        #expect(EnglishLookupForm.description(of: card(term: "was", base: "be")) == "Form of be")
        #expect(EnglishLookupForm.description(of: card(term: "refuse")) == nil)
        #expect(EnglishLookupForm.description(of: card(term: "拒绝", base: "拒")) == nil)
    }
}

@MainActor
struct WordLookupTranslationLayoutTests {
    @Test func theGeneratedGlossAndWordFormFitTheCompactCardAtEachTextSize() throws {
        let sense = SensePresentation(key: "refuse-verb", ordinal: 1, partOfSpeech: "verb",
                                      label: "拒绝；拒绝给予；回绝", keyKind: .publisher,
                                      standing: .unclaimed, metBefore: false)
        let card = LookupCard(term: "refused", lemma: "refuse", heading: "refuse", partOfSpeech: "verb",
                              pronunciation: "/rɪˈfjuːz/", answer: .undecided(reason: nil),
                              sentence: "The application was refused.", alternatives: [sense])
        for textSize in [TextSize.standard, .large] {
            let scale = Scale(textSize)
            for scheme in [ColorScheme.light, .dark] {
                let content = CompactLookupCardView(card: card, wordTranslation: "被拒绝", hasWordContext: true, onMore: {})
                    .frame(width: scale.space.lookupWidth)
                    .background(scheme == .dark ? Color(white: 0.13) : .white)
                    .environment(\.scale, scale)
                    .environment(\.colorScheme, scheme)
                let view = NSHostingView(rootView: content)
                view.layoutSubtreeIfNeeded()
                let wanted = view.fittingSize
                #expect(wanted.width == scale.space.lookupWidth)
                #expect(wanted.height > 0 && wanted.height <= scale.space.cardMaxHeight)
                // Optional review artifacts use the same fixture and native view; no app is launched.
                if let directory = ProcessInfo.processInfo.environment["HUIDICT_TRANSLATION_RENDER_DIR"] {
                    view.frame.size = wanted
                    view.layoutSubtreeIfNeeded()
                    let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    let png = try #require(bitmap.representation(using: .png, properties: [:]))
                    let name = "word-translation-\(textSize.rawValue)-\(scheme == .dark ? "dark" : "light").png"
                    try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
                }
            }
        }
    }
}

import Foundation
import ModelKit
import XiaolaiDictCore

/// Generated translations stay separate from publisher senses and never acquire dictionary keys.
struct WordLookupTranslation: Equatable {
    let question: TranslationQuestion
    let text: String

    init?(_ outcome: TranslationOutcome, question: TranslationQuestion) {
        guard case .translated(let text, by: .localModel) = outcome,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= ModelPrompt.maximumWordTranslationCharacters else { return nil }
        self.question = question
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func text(for current: TranslationQuestion?) -> String? {
        question == current ? text : nil
    }
}

extension TranslationQuestion {
    static func word(_ card: LookupCard, target: String) -> TranslationQuestion? {
        guard !card.term.isEmpty, card.term.count <= ModelPrompt.selectedTextCharacterLimit else { return nil }
        // An unconfirmed dictionary guess must not force the translation into that same guess.
        let confirmed = card.leadingSense.flatMap { sense -> MetSense? in
            sense.standing.isConfirmed ? MetSense(term: card.term, sense: sense.label) : nil
        }
        return TranslationQuestion(sentence: card.term, target: target, met: confirmed,
                                   wordContext: card.sentence ?? "")
    }
}

enum EnglishLookupForm {
    static func description(of card: LookupCard) -> String? {
        let word = card.term.lowercased(), base = card.heading.lowercased()
        guard word != base, base == card.lemma.lowercased(), [word, base].allSatisfy({
            !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isLetter }
        }) else { return nil }
        let part = card.partOfSpeech?.lowercased() ?? ""
        if part.contains("verb") {
            if word.hasSuffix("ed") {
                return String(localized: "Past tense / past participle of \(card.heading)")
            }
            if word.hasSuffix("ing") {
                return String(localized: "-ing form of \(card.heading)")
            }
            if word == base + "s" || word == base + "es"
                || (base.hasSuffix("y") && word == base.dropLast() + "ies") {
                return String(localized: "Third-person singular of \(card.heading)")
            }
        }
        if part.contains("noun"), word.hasSuffix("s") {
            return String(localized: "Plural of \(card.heading)")
        }
        return String(localized: "Form of \(card.heading)")
    }
}

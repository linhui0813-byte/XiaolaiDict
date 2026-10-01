import Foundation
import FoundationModels

/// A bounded generated gloss, with one grammatical reading per labelled line.
/// These labels belong to Qwen's answer; they do not inherit a dictionary sense's part of speech.
public struct WordTranslationGloss: Sendable, Equatable {
    @Generable
    public enum PartOfSpeech: String, Sendable, CaseIterable {
        case noun, verb, adjective, adverb, pronoun, determiner, preposition, conjunction, interjection, numeral, phrase

        public var label: String {
            switch self {
            case .noun: "n."
            case .verb: "v."
            case .adjective: "adj."
            case .adverb: "adv."
            case .pronoun: "pron."
            case .determiner: "det."
            case .preposition: "prep."
            case .conjunction: "conj."
            case .interjection: "interj."
            case .numeral: "num."
            case .phrase: "phr."
            }
        }
    }

    public struct Meaning: Sendable, Equatable {
        public let partOfSpeech: PartOfSpeech
        public let translation: String
    }

    public let meanings: [Meaning]
    public var text: String {
        meanings.map { "\($0.partOfSpeech.label) \($0.translation)" }.joined(separator: "\n")
    }

    public init?(_ output: String) {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= ModelPrompt.maximumWordTranslationCharacters else { return nil }
        let lines = trimmed.split(whereSeparator: \.isNewline)
        guard (1...3).contains(lines.count) else { return nil }
        var readings: [Meaning] = []
        for line in lines {
            let fields = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard fields.count == 2, let part = PartOfSpeech.allCases.first(where: { $0.label == fields[0] }) else { return nil }
            let translation = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            // A second label on the same line would silently assign its gloss the first label.
            let tokens = translation.split { $0.isWhitespace || $0 == ";" || $0 == "；" }
            guard !translation.isEmpty, !tokens.contains(where: { token in PartOfSpeech.allCases.contains { $0.label == token } }),
                  !readings.contains(where: { $0.partOfSpeech == part }) else { return nil }
            readings.append(Meaning(partOfSpeech: part, translation: translation))
        }
        meanings = readings
    }
}

/// Contextual lookup generates exactly one reading; the schema always includes its grammar.
@Generable
public struct GeneratedWordMeaning {
    @Guide(description: "The selected English word's grammatical use, not the grammar of its translation. A passive verb is verb; a participle modifying a noun is adjective.")
    public var partOfSpeech: WordTranslationGloss.PartOfSpeech

    @Guide(description: "Only the selected word's short translation in the requested language. No grammar label, explanation, or surrounding sentence.")
    public var translation: String

    public var labelledText: String { "\(partOfSpeech.label) \(translation)" }
}

/// Without a sentence, a word can have several grammatical readings. No per-request schema.
@Generable
public struct GeneratedWordReadings {
    @Guide(description: "Common readings grouped by English part of speech, with no repeated part of speech.", .count(1...3))
    public var readings: [GeneratedWordMeaning]

    /// Several common meanings can have the same grammar; the compact card gives them one row.
    public var labelledText: String {
        var groups: [(WordTranslationGloss.PartOfSpeech, [String])] = []
        for reading in readings {
            let translation = reading.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            if let index = groups.firstIndex(where: { $0.0 == reading.partOfSpeech }) {
                if !groups[index].1.contains(translation) { groups[index].1.append(translation) }
            } else {
                groups.append((reading.partOfSpeech, [translation]))
            }
        }
        return groups.map { "\($0.0.label) \($0.1.joined(separator: "；"))" }.joined(separator: "\n")
    }
}

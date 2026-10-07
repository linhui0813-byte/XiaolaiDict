import ModelKit
import Observation
import SwiftUI
import XiaolaiDictCore

/// A missing entry is sent to the provider only after a click, once per attempt.
@MainActor
@Observable
final class OnlineWordLookup {
    enum Status: Equatable {
        case ready
        case loading
        case translated(WordLookupTranslation)
        case unavailable
    }

    private var question: TranslationQuestion?
    private var status = Status.ready
    @ObservationIgnored private var task: Task<Void, Never>?

    func status(for question: TranslationQuestion) -> Status {
        self.question == question ? status : .ready
    }

    func reset(for question: TranslationQuestion?) {
        guard self.question != question else { return }
        cancel()
        self.question = question
    }

    func cancel() {
        task?.cancel()
        task = nil
        question = nil
        status = .ready
    }

    @discardableResult
    func start(_ question: TranslationQuestion,
               translate: @escaping @Sendable (TranslationQuestion) async -> TranslationOutcome) -> Task<Void, Never> {
        reset(for: question)
        if let task { return task }
        status = .loading
        let work = Task {
            let outcome = await translate(question)
            guard !Task.isCancelled, self.question == question else { return }
            if let answer = WordLookupTranslation(outcome, question: question) {
                status = .translated(answer)
            } else {
                status = .unavailable
            }
            task = nil
        }
        task = work
        return work
    }
}

/// Shared by the compact and expanded missing-entry cards; expanding never starts another call.
struct OnlineWordLookupView: View {
    @Environment(\.scale) private var scale
    @Environment(\.translation) private var translator
    let lookup: OnlineWordLookup
    let question: TranslationQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: scale.space.line) {
            switch lookup.status(for: question) {
            case .ready:
                lookupButton(retry: false)
            case .loading:
                HStack(spacing: scale.space.inline) {
                    ProgressView().controlSize(.small)
                    Text("Looking up online…")
                }
                .foregroundStyle(.secondary)
            case .translated(let answer):
                ForEach(answer.gloss.meanings, id: \.partOfSpeech) { meaning in
                    HStack(alignment: .firstTextBaseline, spacing: scale.space.inline) {
                        Text(verbatim: meaning.partOfSpeech.label).foregroundStyle(.secondary)
                        Text(verbatim: meaning.translation).fontWeight(.medium)
                    }
                }
                Text("Online translation · DeepSeek")
                    .font(.system(size: scale.text.small))
                    .foregroundStyle(.secondary)
                Text("AI suggestion. Names and coined words may need more context.")
                    .font(.system(size: scale.text.small))
                    .foregroundStyle(.secondary)
                if question.wordContext?.isEmpty == false {
                    Text("Uses the captured sentence")
                        .font(.system(size: scale.text.small))
                        .foregroundStyle(.secondary)
                }
            case .unavailable:
                Text("Online lookup could not return a translation. Check your connection and DeepSeek setup.")
                    .font(.system(size: scale.text.small))
                    .foregroundStyle(.secondary)
                lookupButton(retry: true)
            }
        }
        .font(.system(size: scale.text.body))
        .fixedSize(horizontal: false, vertical: true)
    }

    private func lookupButton(retry: Bool) -> some View {
        Button {
            lookup.start(question, translate: translator.translate)
        } label: {
            Group {
                if retry { Label("Try online lookup again", systemImage: "globe") }
                else { Label("Look up online", systemImage: "globe") }
            }
            .frame(minHeight: Token.Target.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .help(Text("Send this word and any captured sentence to DeepSeek for a suggested translation."))
    }
}

import Foundation
import ModelKit
import XiaolaiDictCore

/// The actual local translation path, with examples that distinguish grammatical readings.
/// No dictionary corpus, downloads, or user reading history are needed for this report.
@MainActor
enum WordTranslationReport {
    static func run() async -> CommandStatus {
        let models = LocalModelAccess(client: ModelClient(), store: .standard())
        guard models.isInstalled else {
            _ = Instrument.write(["installed": false], to: LookupCommand.writeLine)
            return .failure
        }
        await models.prewarm()
        let examples: [(String, String, [String], [String])] = [
            ("refused", "The application was refused.", ["拒绝", "拒"], ["申请"]),
            ("refused", "They refused to sign.", ["拒绝", "拒"], ["他们", "签字"]),
            ("refused", "", ["拒绝", "拒"], []),
            ("approach", "Sometimes an approach that requires more lines of code is actually simpler, because it reduces repetition.", ["方法", "方式", "方案"], ["近似", "代码"]),
            ("continues", "The discussion continues.", ["继续", "持续"], ["讨论"]),
            ("denied", "Her request was denied.", ["拒绝", "驳回", "否决"], ["她", "请求"]),
        ]
        var rows: [[String: Any]] = []
        var passed = true
        for (word, context, expected, excluded) in examples {
            let question = TranslationQuestion(sentence: word, target: "zh-Hans", wordContext: context)
            let started = ContinuousClock.now
            let outcome = await models.translator.translate(question)
            let text: String
            if case .translated(let answer, by: .localModel) = outcome { text = answer }
            else { text = "" }
            let ok = text.count <= ModelPrompt.maximumWordTranslationCharacters && expected.contains(where: text.contains)
                && !excluded.contains(where: text.contains)
                && (word != "refused" || (!context.isEmpty && !context.contains("was"))
                    || ["被", "遭"].contains(where: text.contains))
            passed = passed && ok
            rows.append(["word": word, "context": context, "translation": text,
                         "matchesExpectedMeaning": ok, "milliseconds": Int((ContinuousClock.now - started).milliseconds.rounded())])
        }
        let sentence = "The application was not refused."
        let outcome = await models.translator.translate(TranslationQuestion(sentence: sentence, target: "zh-Hans"))
        let text: String
        if case .translated(let answer, by: .localModel) = outcome { text = answer } else { text = "" }
        let negation = ["未", "没有", "没", "并非", "不"].contains(where: text.contains)
        passed = passed && negation && text.contains("拒")
        rows.append(["sentence": sentence, "translation": text, "preservesNegation": negation])

        let context = "This approach reduces repetition in the code."
        let hinted = TranslationQuestion(sentence: "approach", target: "zh-Hans",
                                          met: .init(term: "approach", sense: "something similar"), wordContext: context)
        let hintedOutcome = await models.translator.translate(hinted)
        let hintedText: String
        if case .translated(let answer, by: .localModel) = hintedOutcome { hintedText = answer }
        else { hintedText = "" }
        let usesContext = ["方法", "方式", "方案"].contains(where: hintedText.contains)
        passed = passed && usesContext
        rows.append(["word": "approach", "context": context, "translation": hintedText,
                     "ignoresMismatchedHint": usesContext])

        let explanation = await models.ask(.explain(SentenceQuestion(sentence: context, term: "approach",
                                                                     senseText: "something similar", target: "zh-Hans")))
        let explained: String
        if case .explanation(let answer)? = explanation { explained = answer } else { explained = "" }
        let explainsUse = ["方法", "方式", "方案"].contains(where: explained.contains)
        passed = passed && explainsUse
        rows.append(["sentence": context, "explanation": explained, "explainsContextInChinese": explainsUse])
        guard Instrument.write(["installed": true, "cases": rows, "passed": passed], to: LookupCommand.writeLine)
        else { return .internalError }
        return passed ? .success : .failure
    }
}

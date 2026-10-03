import Foundation
import ModelKit
import XiaolaiDictCore

/// Bounded live checks of the same provider the GUI uses. Never downloads or starts Qwen.
enum DeepSeekReport {
    static func status(write: (String) -> Bool) -> CommandStatus {
        let configured = DeepSeekClient().isConfigured
        let gone = ModelServiceProcess.presence == .gone
        guard Instrument.write(["provider": "deepseek", "model": DeepSeekConfiguration.model,
                                "configured": configured, "localModelEnabled": false,
                                "localServiceGone": gone], to: write) else { return .internalError }
        return configured && gone ? .success : .failure
    }

    static func measure(into report: inout [String: Any]) async throws -> Bool {
        let access = LocalModelAccess.production()
        report["provider"] = "deepseek"
        report["model"] = DeepSeekConfiguration.model
        report["localModelEnabled"] = false
        report["configured"] = access.isInstalled
        guard access.isInstalled else { return false }
        let sense = await access.ask(.pickSense(SenseQuestion(
            sentence: "The ship's hold was full.", partOfSpeech: "noun",
            senses: ["a grasp or grip", "a space in a ship used to store cargo"])))
        try Task.checkCancellation()
        let selected = TranslationQuestion(sentence: "hold", target: "zh-Hans",
                                           wordContext: "The ship's hold was full.")
        let word = await access.ask(.translate(selected))
        try Task.checkCancellation()
        let sentence = await access.ask(.translate(TranslationQuestion(
            sentence: "The application was not refused.", target: "zh-Hans")))
        try Task.checkCancellation()
        let explanation = await access.ask(.explain(SentenceQuestion(
            sentence: "This approach reduces repetition in the code.", term: "approach", target: "zh-Hans")))
        try Task.checkCancellation()
        let senseOK = sense == .sense(2)
        var wordOK = false, sentenceOK = false, explanationOK = false
        if case .translation(let text)? = word {
            report["wordTranslation"] = text
            wordOK = WordTranslationGloss(text)?.meanings.map(\.partOfSpeech) == [.noun]
                && ["舱", "货仓"].contains(where: text.contains)
        }
        if case .translation(let text)? = sentence {
            report["sentenceTranslation"] = text
            sentenceOK = text.contains("拒") && ["没有", "未", "没", "不", "并非"].contains(where: text.contains)
        }
        if case .explanation(let text)? = explanation {
            report["explanation"] = text
            explanationOK = ["方法", "方式", "方案"].contains(where: text.contains)
        }
        let gone = ModelServiceProcess.presence == .gone
        report["checks"] = ["sense": senseOK, "word": wordOK, "sentence": sentenceOK,
                            "explanation": explanationOK, "localServiceGone": gone]
        return senseOK && wordOK && sentenceOK && explanationOK && gone
    }
}

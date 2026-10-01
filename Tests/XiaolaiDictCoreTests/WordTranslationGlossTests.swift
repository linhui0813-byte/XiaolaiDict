import ModelKit
import Testing

struct WordTranslationGlossTests {
    @Test func eachGeneratedReadingKeepsItsOwnGrammarLabel() throws {
        let gloss = try #require(WordTranslationGloss(" v. 重新打开了\n adj. 被重新打开的 "))
        #expect(gloss.meanings.map(\.partOfSpeech) == [.verb, .adjective])
        #expect(gloss.meanings.map(\.translation) == ["重新打开了", "被重新打开的"])
        #expect(gloss.text == "v. 重新打开了\nadj. 被重新打开的")
        #expect(WordTranslationGloss("n. 方法；途径")?.meanings.first?.partOfSpeech == .noun)
    }

    @Test(arguments: ["", "重新打开", "adjective 被重新打开的", "adj.", "adj.   ",
                      "v. 打开； adj. 被打开的", "v. 打开\nv. 开始", "n. 一\nv. 二\nadj. 三\nadv. 四"])
    func malformedOrUnlabelledAnswersAreNotShown(_ text: String) {
        #expect(WordTranslationGloss(text) == nil)
    }

    @Test func labelsCannotDisguiseAnEchoAndSentenceTranslationsNeedNoLabels() {
        let word = TranslationQuestion(sentence: "reopened", target: "zh-Hans", wordContext: "")
        #expect(!TranslationCheck.isTranslation("v. reopened", for: word))
        #expect(!TranslationCheck.isTranslation("v. 重新打开\nadj. reopened", for: word))
        #expect(!TranslationCheck.isTranslation("v. " + String(repeating: "字", count: 80), for: word))
        #expect(TranslationCheck.isTranslation("v. 重新打开\nadj. 被重新打开的", for: word))
        #expect(TranslationCheck.isTranslation("商店重新开业了。", for:
            TranslationQuestion(sentence: "The shop reopened.", target: "zh-Hans")))
    }
}

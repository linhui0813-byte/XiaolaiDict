import Foundation
import LocalModel
import LocalModelRuntime
import ModelKit

struct Example: Decodable, Sendable {
    let id: String
    let kind: String
    let word: String?
    let context: String
    let expectedAny: [String]?
    let forbiddenAny: [String]?
    let requiredGroups: [[String]]?
    let parts: [String]?
    let senses: [String]?
    let senseIndex: Int?
    let partOfSpeech: String?
    let hint: String?

    var request: ModelRequest {
        switch kind {
        case "word": .translate(TranslationQuestion(sentence: word!, target: "zh-Hans",
            met: hint.map { .init(term: word!, sense: $0) }, wordContext: context))
        case "sense": .pickSense(SenseQuestion(sentence: context, partOfSpeech: partOfSpeech, senses: senses!))
        case "explanation": .explain(SentenceQuestion(sentence: context, term: word!, senseText: hint, target: "zh-Hans"))
        default: .translate(TranslationQuestion(sentence: context, target: "zh-Hans"))
        }
    }

    func check(_ reply: ModelReply) -> Bool {
        if case .sense(let number) = reply { return kind == "sense" && number == senseIndex }
        let text: String
        switch reply {
        case .translation(let value), .explanation(let value): text = value
        default: return false
        }
        guard !(expectedAny ?? []).isEmpty,
              expectedAny!.contains(where: text.contains),
              !(forbiddenAny ?? []).contains(where: text.contains) else { return false }
        guard (requiredGroups ?? []).allSatisfy({ $0.contains(where: text.contains) }) else { return false }
        if let parts {
            guard let readings = WordTranslationGloss(text)?.meanings.map({ $0.partOfSpeech.rawValue }),
                  readings.count == parts.count, Set(readings) == Set(parts) else { return false }
        }
        if case .translate(let question) = request {
            return TranslationCheck.isTranslation(text, for: question)
        }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ConcurrentResult: Sendable {
    let example: Example
    let reply: ModelReply
    let milliseconds: Double
}

func option(_ name: String) -> String? {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func emit(_ report: [String: Any], code: Int32) -> Never {
    let data = try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(code)
}

let choice = option("--model") ?? "4bit"
guard ["4bit", "3bit", "2b4bit"].contains(choice), let file = option("--cases"),
      (choice == "4bit" || option("--store") != nil),
      let cacheMiB = Int(option("--cache-mib") ?? "256"),
      ModelMemoryPolicy.cacheRange.contains(cacheMiB) else {
    emit(["error": "usage: HuiDictModelBenchmark --model 4bit|3bit|2b4bit --cases PATH [--store PATH] [--cache-mib 16...256]"], code: 64)
}
let manifest = switch choice {
case "3bit": ModelManifest.qwen35ThreeBitExperiment
case "2b4bit": ModelManifest.qwen35TwoBExperiment
default: LocalModelSize.standard.manifest
}
let store = option("--store").map { ModelStore(root: URL(filePath: $0)) } ?? .standard()
let examples: [Example]
do {
    examples = try JSONDecoder().decode([Example].self, from: Data(contentsOf: URL(filePath: file)))
} catch {
    emit(["error": "the benchmark cases could not be read or decoded"], code: 64)
}
guard !examples.isEmpty, Set(examples.map(\.id)).count == examples.count,
      examples.allSatisfy({ ["word", "sense", "explanation", "sentence"].contains($0.kind)
          && (!["word", "explanation"].contains($0.kind) || $0.word?.isEmpty == false)
          && ($0.kind != "sense" || $0.senses?.isEmpty == false) }) else {
    emit(["error": "invalid or duplicate benchmark cases"], code: 64)
}
if CommandLine.arguments.contains("--install") {
    guard choice != "4bit" else { emit(["error": "installation is only for the isolated candidate"], code: 64) }
    do {
        try await ModelDownloader(store: store, hosts: [.huggingFace]).install(manifest)
    } catch {
        emit(["blocked": modelFailureDescription(error)], code: 2)
    }
}
guard store.installed(manifest) != nil else {
    emit(["blocked": "pinned model is not installed", "identifier": manifest.identifier], code: 2)
}
let service = ModelService(store: store, manifests: [manifest],
    makeModel: { directory, _ in ModelBackend.model(at: directory, cacheMiB: cacheMiB) })
let clock = ContinuousClock()
let started = clock.now
let prewarm = await service.reply(to: .prewarm)
guard prewarm == .prewarmed else {
    emit(["blocked": "\(prewarm)", "identifier": manifest.identifier,
          "availableBytes": SystemMemory.available() ?? 0, "requiredBytes": manifest.size.peakMemory + ModelSizing.headroom], code: 2)
}
let prewarmElapsed = clock.now - started
let prewarmMS = Double(prewarmElapsed.components.seconds) * 1_000
    + Double(prewarmElapsed.components.attoseconds) / 1e15
var rows: [[String: Any]] = []
for example in examples {
    let begin = clock.now
    let reply = await service.reply(to: example.request)
    let elapsed = clock.now - begin
    let memory = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ModelBackend.memoryUsage()))
    rows.append(["id": example.id, "kind": example.kind, "word": example.word ?? "", "context": example.context,
                 "reply": try JSONSerialization.jsonObject(with: JSONEncoder().encode(reply)),
                 "screeningPassed": example.check(reply), "memory": memory,
                 "milliseconds": Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15])
}
if CommandLine.arguments.contains("--concurrent") {
    let selected = ["word", "sense", "sentence", "explanation"].compactMap { kind in examples.first { $0.kind == kind } }
    let results = await withTaskGroup(of: ConcurrentResult.self, returning: [ConcurrentResult].self) { group in
        for example in selected {
            group.addTask {
                let started = ContinuousClock.now
                let reply = await service.reply(to: example.request)
                let elapsed = ContinuousClock.now - started
                return ConcurrentResult(example: example, reply: reply,
                    milliseconds: Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15)
            }
        }
        var results: [ConcurrentResult] = []
        for await result in group { results.append(result) }
        return results
    }
    for result in results.sorted(by: { $0.example.id < $1.example.id }) {
        rows.append(["id": "concurrent-\(result.example.id)", "kind": "concurrent", "context": result.example.context,
                     "reply": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.reply)),
                     "screeningPassed": result.example.check(result.reply), "milliseconds": result.milliseconds])
    }
}
let memory = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ModelBackend.memoryUsage()))
emit(["identifier": manifest.identifier, "cacheMiB": cacheMiB, "prewarmMilliseconds": prewarmMS,
      "physicalBytes": SystemMemory.physical, "memory": memory, "cases": rows,
      "passed": rows.allSatisfy { $0["screeningPassed"] as? Bool == true }], code: 0)

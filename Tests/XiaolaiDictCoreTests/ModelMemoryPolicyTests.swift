import ModelKit
import Testing

struct ModelMemoryPolicyTests {
    @Test func aPoolOverrideCannotDisableReuseOrGrowWithoutBound() {
        #expect(ModelMemoryPolicy.cacheMiB(configured: 0) == 16)
        #expect(ModelMemoryPolicy.cacheMiB(configured: -100) == 16)
        #expect(ModelMemoryPolicy.cacheMiB(configured: 64) == 64)
        #expect(ModelMemoryPolicy.cacheMiB(configured: Int.max) == 256)
    }

    @Test func theCandidateCannotBecomeAnAutomaticDownloadOrSelection() {
        let candidate = ModelManifest.qwen35ThreeBitExperiment
        #expect(!ModelManifest.all.contains(candidate))
        #expect(candidate.identifier != LocalModelSize.standard.manifest.identifier)
        #expect(candidate.files.contains { $0.path == "model.safetensors" && $0.size == 2_508_701_687 })
        #expect(candidate.size.peakMemory == LocalModelSize.standard.peakMemory,
                "an unmeasured candidate weakened the existing loading guard")
    }

    @Test func theFallbackIsAlsoIsolatedAndUsesTheConservativeGuard() {
        let candidate = ModelManifest.qwen35TwoBExperiment
        #expect(!ModelManifest.all.contains(candidate))
        #expect(candidate.identifier != LocalModelSize.standard.manifest.identifier)
        #expect(candidate.files.contains { $0.path == "model.safetensors" && $0.size == 1_722_271_785 })
        #expect(candidate.size == .standard)
    }
}

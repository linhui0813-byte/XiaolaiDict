import Foundation
import Darwin
import FoundationModels
import MLX
import MLXFoundationModels
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import ModelKit
// The tokenizer macro stores a third-party type without Sendable conformance.
@preconcurrency import Tokenizers

public enum ModelBackend {
    /// The service and benchmark use the same local-only loader and guided generation.
    public static func model(at directory: URL, cacheMiB: Int) -> any FoundationModels.LanguageModel {
        let bytes = ModelMemoryPolicy.cacheMiB(configured: cacheMiB) * 1_048_576
        return MLXLanguageModel(
            configuration: ModelConfiguration(directory: directory),
            capabilities: [.guidedGeneration],
            weightsLocation: { _ in directory },
            load: { _, _ in
                // The adapter initializes its pool immediately before invoking this closure.
                // Set our cap here so initialization cannot silently overwrite it.
                MLX.Memory.cacheLimit = bytes
                return try await loadModelContainer(from: directory, using: #huggingFaceTokenizerLoader())
            })
    }

    public struct MemoryUsage: Codable, Sendable {
        public let footprintBytes: UInt64?
        public let processPeakBytes: UInt64?
        public let gpuActiveBytes: Int
        public let gpuCachedBytes: Int
        public let gpuPeakBytes: Int
        public let cacheLimitBytes: Int
    }

    public static func memoryUsage() -> MemoryUsage {
        let snapshot = MLX.Memory.snapshot()
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return MemoryUsage(
            footprintBytes: status == KERN_SUCCESS ? info.phys_footprint : nil,
            processPeakBytes: status == KERN_SUCCESS ? UInt64(max(0, info.ledger_phys_footprint_peak)) : nil,
            gpuActiveBytes: snapshot.activeMemory, gpuCachedBytes: snapshot.cacheMemory,
            gpuPeakBytes: snapshot.peakMemory, cacheLimitBytes: MLX.Memory.cacheLimit)
    }
}

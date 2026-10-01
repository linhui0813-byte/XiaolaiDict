import Foundation

extension ModelManifest {
    /// Experiment only: excluded from `all`, the setup board, and automatic model selection.
    /// Published bytes are pinned; source conversion provenance and quality still require review.
    public static let qwen35ThreeBitExperiment = ModelManifest(
        size: .standard, repository: "mlx-community/Qwen3.5-4B-3bit",
        revision: "6a87bc4e52f513d6d68397b844db31a255f3fb19",
        files: [
            ("chat_template.jinja", 7_756, "a4aee8afcf2e0711942cf848899be66016f8d14a889ff9ede07bca099c28f715"),
            ("config.json", 3_366, "ad0eb1cdf688fbedbd6f1a85a165bd3258bb41497df5e5858584df8bcf2184f7"),
            ("model.safetensors.index.json", 101_944, "a297c05e365aac2bdd817da091bcff5dbdfb9f0503982743c0fca6405474685b"),
            ("preprocessor_config.json", 390, "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516"),
            ("processor_config.json", 1_300, "14932921ca485d458a04dafd8069fbb0a4505622a48208d19ed247115801385b"),
            ("tokenizer.json", 19_989_343, "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
            ("tokenizer_config.json", 1_139, "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"),
            ("video_preprocessor_config.json", 385, "7768af27c1fafa9cc9011c1dc20067e03f8915e03b63504550e11d5066986d13"),
            ("vocab.json", 6_722_759, "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003"),
            ("model.safetensors", 2_508_701_687, "2d45a057491949fc8f03d924023233beace74eba77da8a9f7bd7112136762d39"),
            ("LICENSE", 11_343, "50cbab8a892c5f2993b8c7351a99182507472def3b1374558308605d99b86b32"),
        ].map { path, size, hash in
            if path == licenceFileName {
                return ModelFile(repository: "Qwen/Qwen3.5-4B",
                                 revision: "ed182e32090db791077e12e0f58d22f3daafa173", path: path, size: Int64(size), sha256: hash)
            }
            return ModelFile(repository: "mlx-community/Qwen3.5-4B-3bit",
                             revision: "6a87bc4e52f513d6d68397b844db31a255f3fb19", path: path, size: Int64(size), sha256: hash,
                             alternates: [.huggingFace: (repository: "mlx-community/Qwen3.5-4B-3bit",
                                                        revision: "6a87bc4e52f513d6d68397b844db31a255f3fb19")])
        })
}

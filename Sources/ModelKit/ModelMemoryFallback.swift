import Foundation

extension ModelManifest {
    /// Isolated 2B fallback screening; excluded from automatic selection and downloads.
    /// Uses the existing 4B admission bound conservatively while its footprint is measured.
    public static let qwen35TwoBExperiment = ModelManifest(
        size: .standard, repository: "mlx-community/Qwen3.5-2B-4bit",
        revision: "674aaa7240b91e8012fcad5d791b7dfe5ba90207",
        files: [
            ("chat_template.jinja", 7_755, "273d8e0e683b885071fb17e08d71e5f2a5ddfb5309756181681de4f5a1822d80"),
            ("config.json", 3_113, "beb7fc5a6e0405fe332821cf1a8ef7b69bb390a8c8933171647de5579debf949"),
            ("model.safetensors", 1_722_271_785, "713fe7e5d3c3965f7106b0d0ee17615f7869c23c8d327996df8c1196fbcf07d5"),
            ("model.safetensors.index.json", 81_722, "8294c05cca7d53a6c33e3db2b379539bd296d054e0b689711b16b6ac93c7e49d"),
            ("preprocessor_config.json", 390, "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516"),
            ("processor_config.json", 1_300, "14932921ca485d458a04dafd8069fbb0a4505622a48208d19ed247115801385b"),
            ("tokenizer.json", 19_989_343, "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
            ("tokenizer_config.json", 1_139, "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"),
            ("video_preprocessor_config.json", 385, "7768af27c1fafa9cc9011c1dc20067e03f8915e03b63504550e11d5066986d13"),
            ("vocab.json", 6_722_759, "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003"),
            ("LICENSE", 11_343, "50cbab8a892c5f2993b8c7351a99182507472def3b1374558308605d99b86b32"),
        ].map { path, size, hash in
            if path == licenceFileName {
                return ModelFile(repository: "Qwen/Qwen3.5-4B",
                                 revision: "ed182e32090db791077e12e0f58d22f3daafa173", path: path, size: Int64(size), sha256: hash)
            }
            return ModelFile(repository: "mlx-community/Qwen3.5-2B-4bit", revision: "674aaa7240b91e8012fcad5d791b7dfe5ba90207", path: path, size: Int64(size), sha256: hash,
                             alternates: [.huggingFace: (repository: "mlx-community/Qwen3.5-2B-4bit", revision: "674aaa7240b91e8012fcad5d791b7dfe5ba90207")])
        })
}

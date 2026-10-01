import DictionaryBridge

/// Licensed sideloaded dictionaries are optional local fixtures, not dependencies of the app.
/// Tests that need them say so and skip when absent; the standard Apple dictionary tests still run.
enum InstalledDictionaryFixtures {
    static func contains(_ names: String...) -> Bool {
        guard let active = try? DictionaryBridge.activeDictionaries() else { return false }
        return names.allSatisfy { name in active.contains { $0.name.contains(name) } }
    }
}

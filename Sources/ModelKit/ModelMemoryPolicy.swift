/// The reusable allocation pool, independently of model weights and the loading guard.
public enum ModelMemoryPolicy {
    public static let defaultsKey = "ModelCacheMiB"
    public static let defaultCacheMiB = 256
    public static let cacheRange = 16...256

    public static func cacheMiB(configured: Int?) -> Int {
        guard let configured else { return defaultCacheMiB }
        return min(max(configured, cacheRange.lowerBound), cacheRange.upperBound)
    }
}

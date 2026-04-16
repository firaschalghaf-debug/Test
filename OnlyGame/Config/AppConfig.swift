import Foundation

// AppConfig is the single source of truth for runtime configuration.
// Credentials come from Secrets.swift (gitignored — see Secrets.swift.template).
enum AppConfig {

    // MARK: - Supabase (read from Secrets.swift)
    static let supabaseURL = Secrets.supabaseURL
    static let supabaseKey = Secrets.supabaseKey

    // MARK: - Crystal Run game constants
    enum CrystalRun {
        static let lanePositions: [CGFloat]    = [-2.2, 0.0, 2.2]
        static let obstacleSpeed: Float        = 24
        static let crystalSpeed: Float         = 26
        static let jumpDuration: TimeInterval  = 0.44
        static let jumpHeight: CGFloat         = 1.6
        static let spawnInterval: TimeInterval = 0.8
        /// 1-in-N chance a spawned object is a crystal (higher = rarer)
        static let crystalRarity               = 5
    }
}

import OSLog

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.winlin.Chartella"

    static let flow = Logger(subsystem: subsystem, category: "ScanFlow")
    static let camera = Logger(subsystem: subsystem, category: "Camera")
    static let detection = Logger(subsystem: subsystem, category: "BorderDetection")
    static let crop = Logger(subsystem: subsystem, category: "Crop")
    static let pdf = Logger(subsystem: subsystem, category: "PDF")
}

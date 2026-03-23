import SwiftUI

// MARK: - FapApp Model

struct FapApp: Identifiable, Equatable {
    var id: String { uid }
    let uid: String
    let name: String
    let description: String
    let author: String
    let category: FapCategory
    let version: String
    let downloadUrl: String
    let iconUrl: String?
    let downloads: Int
    let rating: Float
    var isInstalled: Bool

    init(
        uid: String,
        name: String,
        description: String,
        author: String,
        category: FapCategory,
        version: String,
        downloadUrl: String,
        iconUrl: String? = nil,
        downloads: Int = 0,
        rating: Float = 0,
        isInstalled: Bool = false
    ) {
        self.uid = uid
        self.name = name
        self.description = description
        self.author = author
        self.category = category
        self.version = version
        self.downloadUrl = downloadUrl
        self.iconUrl = iconUrl
        self.downloads = downloads
        self.rating = rating
        self.isInstalled = isInstalled
    }
}

// MARK: - FapCategory

enum FapCategory: String, CaseIterable, Identifiable {
    case games, tools, nfc, subghz, infrared, gpio, bluetooth, usb, media, misc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .games: "Games"
        case .tools: "Tools"
        case .nfc: "NFC"
        case .subghz: "Sub-GHz"
        case .infrared: "Infrared"
        case .gpio: "GPIO"
        case .bluetooth: "Bluetooth"
        case .usb: "USB"
        case .media: "Media"
        case .misc: "Misc"
        }
    }

    var systemImage: String {
        switch self {
        case .games: "gamecontroller"
        case .tools: "wrench.and.screwdriver"
        case .nfc: "creditcard"
        case .subghz: "antenna.radiowaves.left.and.right"
        case .infrared: "light.beacon.max"
        case .gpio: "bolt"
        case .bluetooth: "wave.3.right"
        case .usb: "cable.connector"
        case .media: "music.note"
        case .misc: "shippingbox"
        }
    }
}

// MARK: - Install Status

enum FapInstallStatus: Equatable {
    case idle
    case installing
    case success
    case error(String)
    case requiresConfirmation(approvalId: String)
}

// MARK: - FapHub Catalog

struct FapHubCatalog {

    static let allApps: [FapApp] = [
        FapApp(uid: "wifi_marauder", name: "WiFi Marauder", description: "ESP32 Marauder companion app for WiFi attacks", author: "0xchocolate", category: .bluetooth, version: "0.6.3", downloadUrl: "https://lab.flipper.net/apps/wifi_marauder", downloads: 120000, rating: 4.9),
        FapApp(uid: "flappy_bird", name: "Flappy Bird", description: "Classic Flappy Bird game", author: "xMasterX", category: .games, version: "1.2", downloadUrl: "https://lab.flipper.net/apps/flappy_bird", downloads: 100000, rating: 4.8),
        FapApp(uid: "doom", name: "DOOM", description: "The classic DOOM game ported to Flipper", author: "xMasterX", category: .games, version: "0.9", downloadUrl: "https://lab.flipper.net/apps/doom", downloads: 95000, rating: 4.9),
        FapApp(uid: "ir_remote", name: "Universal IR Remote", description: "Comprehensive IR remote database", author: "Flipper Team", category: .infrared, version: "2.0", downloadUrl: "https://lab.flipper.net/apps/ir_remote", downloads: 90000, rating: 4.8),
        FapApp(uid: "ble_spam", name: "BLE Spam", description: "Bluetooth Low Energy advertisement spam", author: "Willy-JL", category: .bluetooth, version: "2.1", downloadUrl: "https://lab.flipper.net/apps/ble_spam", downloads: 85000, rating: 4.7),
        FapApp(uid: "tetris", name: "Tetris", description: "Classic Tetris game", author: "Flipper Team", category: .games, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/tetris", downloads: 80000, rating: 4.7),
        FapApp(uid: "evil_portal", name: "Evil Portal", description: "Captive portal for credential capture", author: "bigbrodude6119", category: .bluetooth, version: "0.3", downloadUrl: "https://lab.flipper.net/apps/evil_portal", downloads: 75000, rating: 4.7),
        FapApp(uid: "snake", name: "Snake", description: "Classic Snake game", author: "Flipper Team", category: .games, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/snake", downloads: 70000, rating: 4.6),
        FapApp(uid: "nfc_magic", name: "NFC Magic", description: "Write to magic/gen1a NFC cards", author: "Flipper Team", category: .nfc, version: "1.3", downloadUrl: "https://lab.flipper.net/apps/nfc_magic", downloads: 65000, rating: 4.8),
        FapApp(uid: "airtag_scanner", name: "AirTag Scanner", description: "Detect nearby Apple AirTags", author: "Willy-JL", category: .bluetooth, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/airtag_scanner", downloads: 60000, rating: 4.6),
        FapApp(uid: "subghz_bruteforcer", name: "Sub-GHz Bruteforcer", description: "Brute force Sub-GHz protocols", author: "xMasterX", category: .subghz, version: "1.3", downloadUrl: "https://lab.flipper.net/apps/subghz_bruteforcer", downloads: 60000, rating: 4.7),
        FapApp(uid: "qrcode", name: "QR Code", description: "Generate and display QR codes", author: "Willy-JL", category: .tools, version: "1.5", downloadUrl: "https://lab.flipper.net/apps/qrcode", downloads: 55000, rating: 4.6),
        FapApp(uid: "mass_storage", name: "Mass Storage", description: "Expose SD card as USB mass storage", author: "Flipper Team", category: .usb, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/mass_storage", downloads: 55000, rating: 4.6),
        FapApp(uid: "picopass", name: "PicoPass Reader", description: "Read and emulate iClass/PicoPass cards", author: "Flipper Team", category: .nfc, version: "1.5", downloadUrl: "https://lab.flipper.net/apps/picopass", downloads: 50000, rating: 4.8),
        FapApp(uid: "music_player", name: "Music Player", description: "Play RTTTL music files", author: "Flipper Team", category: .media, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/music_player", downloads: 50000, rating: 4.4),
        FapApp(uid: "spectrum_analyzer", name: "Spectrum Analyzer", description: "Real-time RF spectrum visualization", author: "jolcese", category: .subghz, version: "1.2", downloadUrl: "https://lab.flipper.net/apps/spectrum_analyzer", downloads: 45000, rating: 4.7),
        FapApp(uid: "mousejacker", name: "MouseJacker", description: "Exploit wireless mice and keyboards", author: "Flipper Team", category: .subghz, version: "1.1", downloadUrl: "https://lab.flipper.net/apps/mousejacker", downloads: 45000, rating: 4.6),
        FapApp(uid: "barcode_gen", name: "Barcode Generator", description: "Generate and display barcodes", author: "Flipper Team", category: .tools, version: "1.1", downloadUrl: "https://lab.flipper.net/apps/barcode_gen", downloads: 40000, rating: 4.4),
        FapApp(uid: "usb_hid", name: "USB HID", description: "Advanced USB HID controller", author: "Flipper Team", category: .usb, version: "1.5", downloadUrl: "https://lab.flipper.net/apps/usb_hid", downloads: 40000, rating: 4.5),
        FapApp(uid: "gps", name: "GPS", description: "GPS NMEA parser with serial module", author: "Flipper Team", category: .gpio, version: "1.2", downloadUrl: "https://lab.flipper.net/apps/gps", downloads: 35000, rating: 4.5),
        FapApp(uid: "weather_station", name: "Weather Station", description: "Decode weather station sensors", author: "Flipper Team", category: .subghz, version: "1.1", downloadUrl: "https://lab.flipper.net/apps/weather_station", downloads: 35000, rating: 4.4),
        FapApp(uid: "sentry_safe", name: "Sentry Safe Cracker", description: "Brute force Sentry Safe electronic locks", author: "H4ckd4ddy", category: .gpio, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/sentry_safe", downloads: 30000, rating: 4.5),
        FapApp(uid: "video_player", name: "Video Player", description: "Play video files on the display", author: "LTVA1", category: .media, version: "0.5", downloadUrl: "https://lab.flipper.net/apps/video_player", downloads: 30000, rating: 4.3),
        FapApp(uid: "bt_serial", name: "Bluetooth Serial", description: "Bluetooth serial terminal", author: "Flipper Team", category: .bluetooth, version: "1.2", downloadUrl: "https://lab.flipper.net/apps/bt_serial", downloads: 30000, rating: 4.3),
        FapApp(uid: "seader", name: "Seader", description: "Read HID iClass SE cards with SAM", author: "bettse", category: .nfc, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/seader", downloads: 25000, rating: 4.5),
        FapApp(uid: "ir_scope", name: "IR Scope", description: "Visualize and decode IR signals", author: "xMasterX", category: .infrared, version: "1.1", downloadUrl: "https://lab.flipper.net/apps/ir_scope", downloads: 25000, rating: 4.4),
        FapApp(uid: "clock", name: "Clock", description: "Analog and digital clock faces", author: "Flipper Team", category: .misc, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/clock", downloads: 25000, rating: 4.2),
        FapApp(uid: "pocsag_pager", name: "POCSAG Pager", description: "Send POCSAG pager messages", author: "xMasterX", category: .subghz, version: "0.8", downloadUrl: "https://lab.flipper.net/apps/pocsag_pager", downloads: 20000, rating: 4.3),
        FapApp(uid: "dice", name: "Dice Roller", description: "Roll various dice types", author: "Flipper Team", category: .misc, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/dice", downloads: 20000, rating: 4.1),
        FapApp(uid: "signal_generator", name: "Signal Generator", description: "Generate test signals on GPIO", author: "Flipper Team", category: .gpio, version: "1.0", downloadUrl: "https://lab.flipper.net/apps/signal_generator", downloads: 15000, rating: 4.2),
    ]

    static func search(_ query: String) -> [FapApp] {
        let lq = query.lowercased()
        return allApps.filter {
            $0.name.lowercased().contains(lq) ||
            $0.description.lowercased().contains(lq) ||
            $0.author.lowercased().contains(lq)
        }
    }

    static func apps(for category: FapCategory) -> [FapApp] {
        allApps.filter { $0.category == category }
    }
}

// MARK: - FapHubViewModel

@Observable
class FapHubViewModel {
    private let commandExecutor: CommandExecuting

    var searchQuery: String = "" {
        didSet { filterApps() }
    }
    var selectedCategory: FapCategory? = nil {
        didSet { filterApps() }
    }
    var displayedApps: [FapApp] = []
    var installedAppIds: Set<String> = []
    var installStatuses: [String: FapInstallStatus] = [:]
    var isLoadingInstalled: Bool = false
    var error: String?

    /// Pending approval info for confirmation UI
    var pendingApproval: (appId: String, approvalId: String)?

    let categories = FapCategory.allCases

    init(commandExecutor: CommandExecuting) {
        self.commandExecutor = commandExecutor
        filterApps()
    }

    // MARK: - Local Catalog Search & Filter

    func filterApps() {
        var results = FapHubCatalog.allApps

        // Category filter
        if let cat = selectedCategory {
            results = results.filter { $0.category == cat }
        }

        // Search query filter
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let lq = query.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(lq) ||
                $0.description.lowercased().contains(lq) ||
                $0.author.lowercased().contains(lq)
            }
        }

        // Mark installed apps
        results = results.map { app in
            var copy = app
            copy.isInstalled = installedAppIds.contains(app.uid)
            return copy
        }

        // Sort by downloads (most popular first)
        results.sort { $0.downloads > $1.downloads }

        displayedApps = results
    }

    func searchApps() {
        filterApps()
    }

    func clearSearch() {
        searchQuery = ""
        selectedCategory = nil
    }

    // MARK: - Load Installed Apps from Flipper

    func loadInstalledApps() {
        isLoadingInstalled = true
        error = nil

        Task { @MainActor in
            defer { isLoadingInstalled = false }

            // List /ext/apps/ root
            let rootCommand = ExecuteCommand(
                action: .listDirectory,
                args: CommandArgs(path: "/ext/apps"),
                justification: "Scanning installed apps",
                expectedEffect: "List files in /ext/apps/"
            )
            let rootResult = await commandExecutor.execute(rootCommand, sessionId: UUID().uuidString)

            guard rootResult.success, let entries = rootResult.data?.entries else {
                // Not an error -- device may not be connected
                if let err = rootResult.error {
                    error = "Could not scan installed apps: \(err)"
                }
                return
            }

            var foundFaps: Set<String> = []

            // Collect .fap files at root level
            for entry in entries where !entry.isDirectory && entry.name.hasSuffix(".fap") {
                let appId = String(entry.name.dropLast(4)) // remove .fap
                foundFaps.insert(appId)
            }

            // Scan subdirectories (games/, tools/, etc.)
            let subdirs = entries.filter { $0.isDirectory }
            for dir in subdirs {
                let subCommand = ExecuteCommand(
                    action: .listDirectory,
                    args: CommandArgs(path: dir.path),
                    justification: "Scanning installed apps in \(dir.name)",
                    expectedEffect: "List files in \(dir.path)"
                )
                let subResult = await commandExecutor.execute(subCommand, sessionId: UUID().uuidString)
                if let subEntries = subResult.data?.entries {
                    for entry in subEntries where !entry.isDirectory && entry.name.hasSuffix(".fap") {
                        let appId = String(entry.name.dropLast(4))
                        foundFaps.insert(appId)
                    }
                }
            }

            installedAppIds = foundFaps
            filterApps()
        }
    }

    // MARK: - Install App

    func installApp(_ app: FapApp) {
        installStatuses[app.uid] = .installing

        Task { @MainActor in
            let command = ExecuteCommand(
                action: .installFaphubApp,
                args: CommandArgs(
                    command: app.uid,
                    appName: app.name,
                    downloadUrl: app.downloadUrl
                ),
                justification: "User installing \(app.name) from FapHub",
                expectedEffect: "Download and install \(app.name) to Flipper"
            )
            let result = await commandExecutor.execute(command, sessionId: UUID().uuidString)

            if result.requiresConfirmation, let approvalId = result.pendingApprovalId {
                installStatuses[app.uid] = .requiresConfirmation(approvalId: approvalId)
                pendingApproval = (appId: app.uid, approvalId: approvalId)
            } else if result.success {
                installStatuses[app.uid] = .success
                installedAppIds.insert(app.uid)
                filterApps()
                // Clear success status after delay
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run {
                        if case .success = self.installStatuses[app.uid] {
                            self.installStatuses.removeValue(forKey: app.uid)
                        }
                    }
                }
            } else {
                let errorMsg = result.error ?? "Install failed"
                installStatuses[app.uid] = .error(errorMsg)
                error = "Failed to install \(app.name): \(errorMsg)"
            }
        }
    }

    /// Approve a pending install after HIGH risk confirmation
    func approveInstall(approvalId: String, appId: String) {
        installStatuses[appId] = .installing
        pendingApproval = nil

        Task { @MainActor in
            let result = await commandExecutor.approve(approvalId, sessionId: UUID().uuidString)
            if result.success {
                installStatuses[appId] = .success
                installedAppIds.insert(appId)
                filterApps()
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run {
                        if case .success = self.installStatuses[appId] {
                            self.installStatuses.removeValue(forKey: appId)
                        }
                    }
                }
            } else {
                let errorMsg = result.error ?? "Install rejected"
                installStatuses[appId] = .error(errorMsg)
                error = errorMsg
            }
        }
    }

    /// Deny a pending install
    func denyInstall(appId: String) {
        installStatuses.removeValue(forKey: appId)
        pendingApproval = nil
    }

    // MARK: - Uninstall App

    func uninstallApp(_ app: FapApp) {
        installStatuses[app.uid] = .installing

        Task { @MainActor in
            // Try deleting from category-specific and root paths
            let paths = [
                "/ext/apps/\(app.category.rawValue)/\(app.uid).fap",
                "/ext/apps/\(app.uid).fap",
                "/ext/apps/misc/\(app.uid).fap"
            ]

            var deleted = false
            for path in paths {
                let command = ExecuteCommand(
                    action: .delete,
                    args: CommandArgs(path: path),
                    justification: "User uninstalling \(app.name)",
                    expectedEffect: "Delete \(path)"
                )
                let result = await commandExecutor.execute(command, sessionId: UUID().uuidString)

                if result.requiresConfirmation, let approvalId = result.pendingApprovalId {
                    // Delete is HIGH risk -- needs approval
                    installStatuses[app.uid] = .requiresConfirmation(approvalId: approvalId)
                    pendingApproval = (appId: app.uid, approvalId: approvalId)
                    return
                }

                if result.success {
                    deleted = true
                    break
                }
            }

            if deleted {
                installedAppIds.remove(app.uid)
                installStatuses.removeValue(forKey: app.uid)
                filterApps()
            } else {
                installStatuses[app.uid] = .error("Could not find app on device")
                error = "Failed to uninstall \(app.name)"
            }
        }
    }

    // MARK: - Helpers

    func clearError() {
        error = nil
    }

    func refresh() {
        loadInstalledApps()
    }

    func categoryCounts() -> [FapCategory: Int] {
        Dictionary(grouping: FapHubCatalog.allApps, by: \.category)
            .mapValues(\.count)
    }
}

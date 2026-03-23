// SignalArsenalViewModel.swift
// Vesper - AI-powered Flipper Zero controller
// Signal Arsenal: browse, replay, and manage captured signals on Flipper

import Foundation
import Observation

// MARK: - Signal Arsenal Type

/// Signal types for the arsenal. Mirrors the subset from AlchemyLabView's SignalType
/// but scoped to replay-capable types only (no BadUSB).
enum ArsenalSignalType: String, CaseIterable, Identifiable {
    case subGhz = "Sub-GHz"
    case ir = "IR"
    case nfc = "NFC"
    case rfid = "RFID"
    case iButton = "iButton"

    var id: String { rawValue }

    var flipperDirectory: String {
        switch self {
        case .subGhz: "/ext/subghz"
        case .ir: "/ext/infrared"
        case .nfc: "/ext/nfc"
        case .rfid: "/ext/lfrfid"
        case .iButton: "/ext/ibutton"
        }
    }

    var replayAction: CommandAction {
        switch self {
        case .subGhz: .subghzTransmit
        case .ir: .irTransmit
        case .nfc: .nfcEmulate
        case .rfid: .rfidEmulate
        case .iButton: .ibuttonEmulate
        }
    }

    var icon: String {
        switch self {
        case .subGhz: "antenna.radiowaves.left.and.right"
        case .ir: "dot.radiowaves.right"
        case .nfc: "wave.3.right"
        case .rfid: "sensor.tag.radiowaves.forward"
        case .iButton: "key.fill"
        }
    }

    var replayVerb: String {
        switch self {
        case .subGhz, .ir: "Transmit"
        case .nfc, .rfid, .iButton: "Emulate"
        }
    }
}

// MARK: - Signal Entry

struct SignalEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let fileName: String
    let path: String
    let type: ArsenalSignalType
    let size: Int64

    init(
        id: String = UUID().uuidString,
        name: String,
        fileName: String,
        path: String,
        type: ArsenalSignalType,
        size: Int64
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.path = path
        self.type = type
        self.size = size
    }
}

// MARK: - View Model

@Observable
class SignalArsenalViewModel {
    private let commandExecutor: CommandExecuting

    // ── State ──────────────────────────────────────────────
    var selectedType: ArsenalSignalType = .subGhz
    var signals: [SignalEntry] = []
    var searchQuery: String = ""
    var isLoading: Bool = false
    var isReplaying: Bool = false
    var isDeleting: Bool = false
    var error: String?
    var message: String?

    /// Tracks signal counts across all types (loaded lazily)
    var signalCounts: [ArsenalSignalType: Int] = [:]

    // ── Computed ───────────────────────────────────────────

    var filteredSignals: [SignalEntry] {
        guard !searchQuery.isEmpty else { return signals }
        let query = searchQuery.lowercased()
        return signals.filter {
            $0.name.lowercased().contains(query) ||
            $0.fileName.lowercased().contains(query)
        }
    }

    var totalSignalCount: Int {
        signalCounts.values.reduce(0, +)
    }

    // ── Init ──────────────────────────────────────────────

    init(commandExecutor: CommandExecuting) {
        self.commandExecutor = commandExecutor
    }

    // ── Load Signals ──────────────────────────────────────

    /// Load signals for the currently selected type from the Flipper filesystem.
    func loadSignals() {
        isLoading = true
        error = nil

        let type = selectedType

        Task { @MainActor in
            let command = ExecuteCommand(
                action: .listDirectory,
                args: CommandArgs(path: type.flipperDirectory),
                justification: "Loading \(type.rawValue) signals from Flipper",
                expectedEffect: "List files in \(type.flipperDirectory)"
            )

            let result = await commandExecutor.execute(command, sessionId: "signal-arsenal")

            if result.success, let entries = result.data?.entries {
                signals = entries
                    .filter { !$0.isDirectory }
                    .map { entry in
                        SignalEntry(
                            name: (entry.name as NSString).deletingPathExtension,
                            fileName: entry.name,
                            path: entry.path,
                            type: type,
                            size: entry.size
                        )
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                // Update count for this type
                signalCounts[type] = signals.count
            } else {
                let errorMsg = result.error ?? "Failed to load signals"
                // Don't show error for empty directories
                if errorMsg.lowercased().contains("not found") || errorMsg.lowercased().contains("no such") {
                    signals = []
                    signalCounts[type] = 0
                } else {
                    error = errorMsg
                    signals = []
                }
            }

            isLoading = false
        }
    }

    /// Load signal counts for all types (background scan).
    func loadAllCounts() {
        Task { @MainActor in
            for type in ArsenalSignalType.allCases {
                let command = ExecuteCommand(
                    action: .listDirectory,
                    args: CommandArgs(path: type.flipperDirectory),
                    justification: "Counting \(type.rawValue) signals",
                    expectedEffect: "List files in \(type.flipperDirectory)"
                )

                let result = await commandExecutor.execute(command, sessionId: "signal-arsenal")

                if result.success, let entries = result.data?.entries {
                    signalCounts[type] = entries.filter { !$0.isDirectory }.count
                } else {
                    signalCounts[type] = 0
                }
            }
        }
    }

    /// Switch selected type and reload.
    func selectType(_ type: ArsenalSignalType) {
        guard type != selectedType else { return }
        selectedType = type
        signals = []
        searchQuery = ""
        loadSignals()
    }

    // ── Replay Signal ─────────────────────────────────────

    /// Replay (transmit/emulate) a signal. This is MEDIUM risk and may require confirmation.
    func replaySignal(_ signal: SignalEntry) {
        isReplaying = true
        error = nil
        message = nil

        Task { @MainActor in
            let command = ExecuteCommand(
                action: signal.type.replayAction,
                args: CommandArgs(path: signal.path),
                justification: "\(signal.type.replayVerb) signal: \(signal.name)",
                expectedEffect: "\(signal.type.replayVerb) \(signal.type.rawValue) signal from \(signal.path)"
            )

            let result = await commandExecutor.execute(command, sessionId: "signal-arsenal")

            if result.requiresConfirmation {
                message = "Approval required to \(signal.type.replayVerb.lowercased()) \(signal.name)"
            } else if result.success {
                message = "\(signal.type.replayVerb) complete: \(signal.name)"
            } else {
                error = result.error ?? "\(signal.type.replayVerb) failed"
            }

            isReplaying = false
        }
    }

    // ── Delete Signal ─────────────────────────────────────

    /// Delete a signal file from the Flipper. This is HIGH risk.
    func deleteSignal(_ signal: SignalEntry) {
        isDeleting = true
        error = nil
        message = nil

        Task { @MainActor in
            let command = ExecuteCommand(
                action: .delete,
                args: CommandArgs(path: signal.path),
                justification: "Delete signal: \(signal.name)",
                expectedEffect: "Remove file \(signal.path) from Flipper"
            )

            let result = await commandExecutor.execute(command, sessionId: "signal-arsenal")

            if result.requiresConfirmation {
                message = "Approval required to delete \(signal.name)"
            } else if result.success {
                signals.removeAll { $0.id == signal.id }
                signalCounts[signal.type] = max(0, (signalCounts[signal.type] ?? 1) - 1)
                message = "Deleted \(signal.name)"
            } else {
                error = result.error ?? "Delete failed"
            }

            isDeleting = false
        }
    }

    // ── Helpers ───────────────────────────────────────────

    func clearMessage() {
        message = nil
    }

    func clearError() {
        error = nil
    }

    static func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }
}

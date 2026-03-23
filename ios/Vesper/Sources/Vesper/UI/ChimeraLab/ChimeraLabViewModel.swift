// ChimeraLabViewModel.swift
// Vesper - AI-powered Flipper Zero controller
// RF Chimera - Signal Fusion Laboratory

import Foundation
import Observation

// MARK: - Mutation Mode

enum MutationMode: String, CaseIterable, Identifiable {
    case blend
    case interleave
    case layer
    case frequencyHop = "frequency_hop"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blend: return "Blend"
        case .interleave: return "Interleave"
        case .layer: return "Layer"
        case .frequencyHop: return "Frequency Hop"
        }
    }

    var description: String {
        switch self {
        case .blend:
            return "Merge data sections from source signals into a unified stream"
        case .interleave:
            return "Alternate data blocks from each source signal in sequence"
        case .layer:
            return "Concatenate signals with frequency and timing offsets"
        case .frequencyHop:
            return "Cycle through source frequencies during transmission"
        }
    }

    var systemImage: String {
        switch self {
        case .blend: return "waveform.path"
        case .interleave: return "arrow.triangle.swap"
        case .layer: return "square.3.layers.3d"
        case .frequencyHop: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Signal Source Type

enum ChimeraSignalType: String, CaseIterable, Identifiable {
    case subghz = "Sub-GHz"
    case infrared = "IR"
    case nfc = "NFC"
    case rfid = "RFID"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .subghz: return "antenna.radiowaves.left.and.right"
        case .infrared: return "dot.radiowaves.right"
        case .nfc: return "wave.3.right"
        case .rfid: return "sensor.tag.radiowaves.forward"
        }
    }

    var flipperDirectory: String {
        switch self {
        case .subghz: return "/ext/subghz"
        case .infrared: return "/ext/infrared"
        case .nfc: return "/ext/nfc"
        case .rfid: return "/ext/lfrfid"
        }
    }

    var fileExtension: String {
        switch self {
        case .subghz: return ".sub"
        case .infrared: return ".ir"
        case .nfc: return ".nfc"
        case .rfid: return ".rfid"
        }
    }

    var transmitAction: CommandAction {
        switch self {
        case .subghz: return .subghzTransmit
        case .infrared: return .irTransmit
        case .nfc: return .nfcEmulate
        case .rfid: return .rfidEmulate
        }
    }
}

// MARK: - Source Signal

struct SourceSignal: Identifiable, Equatable {
    let id: String
    var name: String
    var path: String
    var content: String
    var type: ChimeraSignalType

    init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        content: String,
        type: ChimeraSignalType
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.content = content
        self.type = type
    }
}

// MARK: - Chimera Signal

struct ChimeraSignal: Identifiable, Equatable {
    let id: String
    var name: String
    var sourceSignals: [SourceSignal]
    var mutationMode: MutationMode
    var content: String
    var signalType: ChimeraSignalType

    init(
        id: String = UUID().uuidString,
        name: String,
        sourceSignals: [SourceSignal],
        mutationMode: MutationMode,
        content: String,
        signalType: ChimeraSignalType
    ) {
        self.id = id
        self.name = name
        self.sourceSignals = sourceSignals
        self.mutationMode = mutationMode
        self.content = content
        self.signalType = signalType
    }
}

// MARK: - ViewModel

@Observable
class ChimeraLabViewModel {
    private let commandExecutor: CommandExecuting

    // MARK: - State

    var sourceSignals: [SourceSignal] = []
    var selectedMutationMode: MutationMode = .blend
    var chimeraOutput: String?
    var chimeraName: String = "chimera"
    var exportPath: String = "/ext/subghz"
    var outputSignalType: ChimeraSignalType = .subghz

    // Loading states
    var isLoading: Bool = false
    var isSynthesizing: Bool = false
    var isExporting: Bool = false
    var isTransmitting: Bool = false
    var error: String?
    var successMessage: String?

    // Signal loading input
    var signalLoadPath: String = ""

    // MARK: - Init

    init(commandExecutor: CommandExecuting) {
        self.commandExecutor = commandExecutor
    }

    // MARK: - Source Signal Management

    /// Load a signal file from the Flipper and add it as a source signal.
    func loadSourceSignal(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Please enter a file path"
            return
        }

        isLoading = true
        error = nil

        Task { @MainActor in
            let command = ExecuteCommand(
                action: .readFile,
                args: CommandArgs(path: trimmed),
                justification: "Read signal file for chimera fusion",
                expectedEffect: "Read signal file content from Flipper"
            )

            let result = await commandExecutor.execute(command, sessionId: "chimera-lab-\(UUID().uuidString)")

            if result.success, let content = result.data?.content {
                let name = (trimmed as NSString).lastPathComponent
                let type = detectSignalType(path: trimmed)

                let source = SourceSignal(
                    name: name,
                    path: trimmed,
                    content: content,
                    type: type
                )
                sourceSignals.append(source)
                signalLoadPath = ""
            } else {
                error = result.error ?? "Failed to read signal file"
            }

            isLoading = false
        }
    }

    func removeSourceSignal(at offsets: IndexSet) {
        sourceSignals.remove(atOffsets: offsets)
    }

    func removeSourceSignal(id: String) {
        sourceSignals.removeAll { $0.id == id }
    }

    // MARK: - Synthesis

    /// Fuse selected source signals using the chosen mutation mode.
    func synthesize() {
        guard sourceSignals.count >= 2 else {
            error = "Select at least 2 signals to fuse"
            return
        }

        isSynthesizing = true
        error = nil
        chimeraOutput = nil

        Task { @MainActor in
            // Build a description of what we want to fuse
            let signalDescriptions = sourceSignals.enumerated().map { index, signal in
                "Signal \(index + 1) (\(signal.name), \(signal.type.rawValue)):\n\(signal.content.prefix(500))"
            }.joined(separator: "\n\n")

            let fusionPrompt = """
            Fuse the following \(sourceSignals.count) signals using \(selectedMutationMode.displayName) mode.

            Mode description: \(selectedMutationMode.description)

            \(signalDescriptions)

            Generate a valid Flipper Zero \(outputSignalType.rawValue) file that combines these signals. \
            Output only the file content, no explanations.
            """

            let command = ExecuteCommand(
                action: .forgePayload,
                args: CommandArgs(
                    prompt: fusionPrompt,
                    payloadType: outputSignalType == .subghz ? "subghz" : outputSignalType.rawValue.lowercased()
                ),
                justification: "Chimera signal fusion: \(selectedMutationMode.displayName) mode with \(sourceSignals.count) sources",
                expectedEffect: "AI generates a fused signal combining source signals"
            )

            let result = await commandExecutor.execute(command, sessionId: "chimera-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                successMessage = "Awaiting approval for signal fusion..."
                isSynthesizing = false
                return
            }

            if result.success, let content = result.data?.content {
                // If AI returned something, use it
                chimeraOutput = content
            } else {
                // Fallback: do a local fusion
                chimeraOutput = localFusion()
            }

            isSynthesizing = false
        }
    }

    // MARK: - Export

    /// Write the chimera signal to the Flipper filesystem.
    func exportChimera(name: String? = nil, path: String? = nil) {
        guard let output = chimeraOutput else {
            error = "No chimera signal to export. Synthesize first."
            return
        }

        let saveName = sanitizeFilename(name ?? chimeraName)
        let savePath = (path ?? exportPath) + "/\(saveName)\(outputSignalType.fileExtension)"

        isExporting = true
        error = nil
        successMessage = nil

        Task { @MainActor in
            let command = ExecuteCommand(
                action: .writeFile,
                args: CommandArgs(
                    path: savePath,
                    content: output
                ),
                justification: "Export chimera signal to Flipper",
                expectedEffect: "Write fused signal file to \(savePath)"
            )

            let result = await commandExecutor.execute(command, sessionId: "chimera-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                successMessage = "Awaiting approval to write chimera file..."
            } else if result.success {
                successMessage = "Chimera exported to \(savePath)"
            } else {
                error = result.error ?? "Failed to export chimera"
            }

            isExporting = false
        }
    }

    // MARK: - Transmit

    /// Transmit the chimera signal using the appropriate protocol.
    func transmitChimera() {
        guard let output = chimeraOutput else {
            error = "No chimera signal to transmit. Synthesize first."
            return
        }

        isTransmitting = true
        error = nil
        successMessage = nil

        Task { @MainActor in
            // Write to a temp file first, then transmit
            let tempName = "_chimera_temp"
            let tempPath = "\(outputSignalType.flipperDirectory)/\(tempName)\(outputSignalType.fileExtension)"

            let writeCommand = ExecuteCommand(
                action: .writeFile,
                args: CommandArgs(
                    path: tempPath,
                    content: output
                ),
                justification: "Write temporary chimera file for transmission",
                expectedEffect: "Write temp chimera signal to Flipper"
            )

            let writeResult = await commandExecutor.execute(writeCommand, sessionId: "chimera-lab-\(UUID().uuidString)")

            if writeResult.requiresConfirmation {
                successMessage = "Awaiting approval to write temp file..."
                isTransmitting = false
                return
            }

            guard writeResult.success else {
                error = writeResult.error ?? "Failed to write temp file for transmission"
                isTransmitting = false
                return
            }

            // Now transmit
            let txCommand = ExecuteCommand(
                action: outputSignalType.transmitAction,
                args: CommandArgs(path: tempPath),
                justification: "Transmit chimera signal via \(outputSignalType.rawValue)",
                expectedEffect: "Transmit fused chimera signal"
            )

            let txResult = await commandExecutor.execute(txCommand, sessionId: "chimera-lab-\(UUID().uuidString)")

            if txResult.requiresConfirmation {
                successMessage = "Awaiting approval for transmission..."
            } else if txResult.success {
                successMessage = "Chimera transmitted via \(outputSignalType.rawValue)"
            } else {
                error = txResult.error ?? "Transmission failed"
            }

            isTransmitting = false
        }
    }

    // MARK: - State Management

    func clearError() {
        error = nil
    }

    func clearSuccess() {
        successMessage = nil
    }

    func reset() {
        sourceSignals.removeAll()
        chimeraOutput = nil
        chimeraName = "chimera"
        error = nil
        successMessage = nil
        isSynthesizing = false
        isExporting = false
        isTransmitting = false
    }

    // MARK: - Helpers

    private func detectSignalType(path: String) -> ChimeraSignalType {
        let lower = path.lowercased()
        if lower.hasSuffix(".sub") || lower.contains("/subghz/") { return .subghz }
        if lower.hasSuffix(".ir") || lower.contains("/infrared/") { return .infrared }
        if lower.hasSuffix(".nfc") || lower.contains("/nfc/") { return .nfc }
        if lower.hasSuffix(".rfid") || lower.contains("/lfrfid/") { return .rfid }
        return .subghz
    }

    private func sanitizeFilename(_ name: String) -> String {
        let cleaned = name.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-" }
            .map { String($0) }
            .joined()
        return cleaned.isEmpty ? "chimera" : String(cleaned.prefix(40))
    }

    /// Local fallback fusion when AI is unavailable.
    private func localFusion() -> String {
        guard !sourceSignals.isEmpty else { return "" }

        switch selectedMutationMode {
        case .blend:
            // Merge: take data sections and concatenate
            let merged = sourceSignals.map { $0.content }.joined(separator: "\n")
            return wrapAsSubGhz(data: merged, name: chimeraName)

        case .interleave:
            // Interleave lines from each source
            let allLines = sourceSignals.map { $0.content.components(separatedBy: .newlines) }
            let maxLines = allLines.map(\.count).max() ?? 0
            var interleaved: [String] = []
            for i in 0..<maxLines {
                for lines in allLines {
                    if i < lines.count {
                        interleaved.append(lines[i])
                    }
                }
            }
            return wrapAsSubGhz(data: interleaved.joined(separator: "\n"), name: chimeraName)

        case .layer:
            // Concatenate with separator comments
            var layered = ""
            for (index, signal) in sourceSignals.enumerated() {
                layered += "# Layer \(index + 1): \(signal.name)\n"
                layered += signal.content + "\n"
            }
            return wrapAsSubGhz(data: layered, name: chimeraName)

        case .frequencyHop:
            // Extract frequencies and data, cycle through them
            var sections: [String] = []
            for signal in sourceSignals {
                sections.append("# Hop source: \(signal.name)\n\(signal.content)")
            }
            return wrapAsSubGhz(data: sections.joined(separator: "\n"), name: chimeraName)
        }
    }

    private func wrapAsSubGhz(data: String, name: String) -> String {
        // Extract RAW_Data lines from source content if present
        let dataLines = data.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("RAW_Data:") }
            .joined(separator: "\n")

        let rawData = dataLines.isEmpty ? "RAW_Data: 500 -500 500 -500" : dataLines

        return """
        Filetype: Flipper SubGhz RAW File
        Version: 1
        # Generated by RF Chimera
        Frequency: 433920000
        Preset: FuriHalSubGhzPresetOok650Async
        Protocol: RAW
        Name: \(name)
        \(rawData)
        """
    }
}

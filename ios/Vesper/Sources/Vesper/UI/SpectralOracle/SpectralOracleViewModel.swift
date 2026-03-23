// SpectralOracleViewModel.swift
// Vesper - AI-powered Flipper Zero controller
// AI Signal Intelligence - ported from Android SpectralOracleViewModel

import Foundation
import Observation

// MARK: - Analysis Type

enum AnalysisType: String, CaseIterable, Identifiable {
    case fullAnalysis
    case protocolId
    case vulnerabilityScan
    case exploitGen
    case manufacturerId
    case threatAssessment
    case counterMeasures
    case patternLearn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullAnalysis: "Full Analysis"
        case .protocolId: "Protocol ID"
        case .vulnerabilityScan: "Vuln Scan"
        case .exploitGen: "Exploit Gen"
        case .manufacturerId: "Manufacturer ID"
        case .threatAssessment: "Threat Assessment"
        case .counterMeasures: "Countermeasures"
        case .patternLearn: "Pattern Learn"
        }
    }

    var icon: String {
        switch self {
        case .fullAnalysis: "sparkles"
        case .protocolId: "magnifyingglass"
        case .vulnerabilityScan: "shield.lefthalf.filled"
        case .exploitGen: "bolt.shield"
        case .manufacturerId: "building.2"
        case .threatAssessment: "exclamationmark.triangle"
        case .counterMeasures: "hand.raised"
        case .patternLearn: "brain"
        }
    }
}

// MARK: - Oracle Risk Level

enum OracleRiskLevel: String, CaseIterable {
    case critical
    case high
    case elevated
    case moderate
    case low
    case minimal

    var displayName: String {
        switch self {
        case .critical: "Critical"
        case .high: "High"
        case .elevated: "Elevated"
        case .moderate: "Moderate"
        case .low: "Low"
        case .minimal: "Minimal"
        }
    }

    var emoji: String {
        switch self {
        case .critical: "🔴"
        case .high: "🟠"
        case .elevated: "🟡"
        case .moderate: "🟢"
        case .low: "🟢"
        case .minimal: "🔵"
        }
    }
}

// MARK: - Vulnerability Severity

enum VulnerabilitySeverity: String, CaseIterable {
    case critical
    case high
    case medium
    case low
    case info
}

// MARK: - Signal File

struct SignalFile: Identifiable, Equatable {
    let id: String
    let name: String
    let fileName: String
    let path: String
    let signalType: SignalType
    let size: Int64

    init(
        id: String = UUID().uuidString,
        name: String,
        fileName: String,
        path: String,
        signalType: SignalType,
        size: Int64
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.path = path
        self.signalType = signalType
        self.size = size
    }
}

// MARK: - Vulnerability Item

struct VulnItem: Identifiable {
    let id = UUID().uuidString
    let name: String
    let description: String
    let severity: VulnerabilitySeverity
}

// MARK: - Exploit Item

struct ExploitItem: Identifiable {
    let id = UUID().uuidString
    let name: String
    let description: String
    let difficulty: String
}

// MARK: - Protocol Info

struct ProtocolInfo {
    let name: String
    let family: String
    let encoding: String
    let isEncrypted: Bool
    let isRollingCode: Bool
    let confidence: Float
}

// MARK: - Oracle Analysis Result

struct OracleAnalysisResult: Identifiable {
    let id = UUID().uuidString
    let signalName: String
    let frequency: String
    let analysisType: AnalysisType
    let summary: String
    let protocolInfo: ProtocolInfo
    let vulnerabilities: [VulnItem]
    let exploits: [ExploitItem]
    let threatLevel: OracleRiskLevel
    let threatAnalysis: String
    let recommendations: [String]
    let rawResponse: String
    let timestamp: Date
}

// MARK: - Analysis History Entry

struct AnalysisHistoryEntry: Identifiable {
    let id = UUID().uuidString
    let signalName: String
    let analysisType: AnalysisType
    let timestamp: Date
    let riskLevel: OracleRiskLevel
    let summary: String
}

// MARK: - View Model

@Observable
class SpectralOracleViewModel {
    private let commandExecutor: CommandExecuting
    private let vesperAgent: VesperAgent

    // Signal browser state
    var availableSignals: [SignalFile] = []
    var isLoadingSignals: Bool = false
    var signalLoadError: String?

    // Selection state
    var selectedSignal: SignalFile?
    var selectedAnalysisType: AnalysisType = .fullAnalysis

    // Signal content preview
    var signalContent: String?
    var isLoadingContent: Bool = false

    // Analysis state
    var isAnalyzing: Bool = false
    var analysisProgress: String = ""
    var analysisResult: OracleAnalysisResult?
    var error: String?

    // History
    var analysisHistory: [AnalysisHistoryEntry] = []

    // Raw response dialog
    var showRawResponse: Bool = false

    // MARK: - Init

    init(commandExecutor: CommandExecuting, vesperAgent: VesperAgent) {
        self.commandExecutor = commandExecutor
        self.vesperAgent = vesperAgent
    }

    // MARK: - Signal Loading

    func loadAvailableSignals() {
        isLoadingSignals = true
        signalLoadError = nil

        let scanDirs: [(String, SignalType)] = [
            ("/ext/subghz", .subGhz),
            ("/ext/infrared", .ir),
            ("/ext/nfc", .nfc),
            ("/ext/lfrfid", .rfid),
            ("/ext/ibutton", .iButton),
        ]

        Task {
            var allSignals: [SignalFile] = []

            for (dir, signalType) in scanDirs {
                let result = await commandExecutor.execute(
                    ExecuteCommand(
                        action: .listDirectory,
                        args: CommandArgs(path: dir),
                        justification: "Loading signal files for Spectral Oracle analysis",
                        expectedEffect: "List files in \(dir)"
                    ),
                    sessionId: "spectral-oracle"
                )

                if result.success, let entries = result.data?.entries {
                    let ext = signalType.fileExtension
                    let filtered = entries.filter { !$0.isDirectory && $0.name.hasSuffix(".\(ext)") }
                    for entry in filtered {
                        let displayName = (entry.name as NSString).deletingPathExtension
                        allSignals.append(
                            SignalFile(
                                name: displayName,
                                fileName: entry.name,
                                path: entry.path,
                                signalType: signalType,
                                size: entry.size
                            )
                        )
                    }
                }
            }

            availableSignals = allSignals.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            isLoadingSignals = false

            if allSignals.isEmpty {
                signalLoadError = "No signal files found on Flipper. Capture some signals first."
            }
        }
    }

    // MARK: - Signal Selection

    func selectSignal(_ signal: SignalFile?) {
        selectedSignal = signal
        analysisResult = nil
        signalContent = nil

        if let signal {
            loadSignalContent(path: signal.path)
        }
    }

    // MARK: - Content Loading

    func loadSignalContent(path: String) {
        isLoadingContent = true

        Task {
            let result = await commandExecutor.execute(
                ExecuteCommand(
                    action: .readFile,
                    args: CommandArgs(path: path),
                    justification: "Reading signal file for preview",
                    expectedEffect: "Read file content from \(path)"
                ),
                sessionId: "spectral-oracle"
            )

            if result.success, let content = result.data?.content {
                signalContent = content
            } else {
                signalContent = nil
                error = "Failed to read signal file: \(result.error ?? "Unknown error")"
            }
            isLoadingContent = false
        }
    }

    // MARK: - Analysis

    func analyzeSignal() {
        guard let signal = selectedSignal else { return }

        isAnalyzing = true
        error = nil
        analysisResult = nil
        analysisProgress = "Preparing signal data..."

        Task {
            // Step 1: Read the signal file if not already loaded
            var content = signalContent
            if content == nil {
                analysisProgress = "Reading signal file..."
                let readResult = await commandExecutor.execute(
                    ExecuteCommand(
                        action: .readFile,
                        args: CommandArgs(path: signal.path),
                        justification: "Reading signal file for AI analysis",
                        expectedEffect: "Read signal content for analysis"
                    ),
                    sessionId: "spectral-oracle"
                )
                if readResult.success, let readContent = readResult.data?.content {
                    content = readContent
                    signalContent = readContent
                } else {
                    error = "Failed to read signal file: \(readResult.error ?? "Unknown error")"
                    isAnalyzing = false
                    return
                }
            }

            guard let fileContent = content else {
                error = "No signal content available"
                isAnalyzing = false
                return
            }

            // Step 2: Build the analysis prompt
            analysisProgress = "Consulting the Oracle..."

            let analysisPrompt = buildAnalysisPrompt(
                signal: signal,
                content: fileContent,
                analysisType: selectedAnalysisType
            )

            // Step 3: Send through VesperAgent chat to leverage the existing AI pipeline
            await vesperAgent.sendMessage(analysisPrompt)

            // Step 4: Extract the AI response from conversation state
            analysisProgress = "Parsing results..."

            let messages = vesperAgent.conversationState.messages
            if let lastAssistant = messages.last(where: { $0.role == .assistant }),
               let aiResponse = lastAssistant.content, !aiResponse.isEmpty {

                let result = parseAIResponse(
                    aiResponse,
                    signal: signal,
                    analysisType: selectedAnalysisType
                )
                analysisResult = result

                // Add to history
                let historyEntry = AnalysisHistoryEntry(
                    signalName: signal.name,
                    analysisType: selectedAnalysisType,
                    timestamp: Date(),
                    riskLevel: result.threatLevel,
                    summary: result.summary
                )
                analysisHistory.insert(historyEntry, at: 0)
                if analysisHistory.count > 20 {
                    analysisHistory = Array(analysisHistory.prefix(20))
                }

                analysisProgress = "Analysis complete"
            } else {
                error = vesperAgent.conversationState.error ?? "No analysis response received from AI"
            }

            isAnalyzing = false
        }
    }

    // MARK: - Prompt Building

    private func buildAnalysisPrompt(signal: SignalFile, content: String, analysisType: AnalysisType) -> String {
        let truncatedContent: String
        if content.count > 3000 {
            truncatedContent = String(content.prefix(3000)) + "\n... [truncated]"
        } else {
            truncatedContent = content
        }

        let instructions: String
        switch analysisType {
        case .fullAnalysis:
            instructions = "Provide complete signal intelligence: protocol identification, vulnerabilities, exploits, threat assessment, and recommendations."
        case .protocolId:
            instructions = "Focus on protocol identification: match against known protocols, encoding scheme, bit rate, packet structure."
        case .vulnerabilityScan:
            instructions = "Identify all security weaknesses: encryption analysis, rolling code flaws, replay susceptibility, timing attacks. Rate each: CRITICAL/HIGH/MEDIUM/LOW/INFO."
        case .exploitGen:
            instructions = "For each vulnerability, describe exploit technique, steps, success probability, detection risks, and legal warnings."
        case .manufacturerId:
            instructions = "Identify the manufacturer, product line, security history, and known CVEs."
        case .threatAssessment:
            instructions = "Evaluate overall risk level, attack surface, most likely attack scenarios, impact if compromised, and priority actions."
        case .counterMeasures:
            instructions = "Provide defensive countermeasures: attack detection, jamming countermeasures, secure alternatives, monitoring recommendations."
        case .patternLearn:
            instructions = "Extract learnable features: signal fingerprint, distinguishing characteristics, classification features, similar signals."
        }

        return """
        [SPECTRAL ORACLE - SIGNAL INTELLIGENCE ANALYSIS]

        You are Spectral Oracle, an elite RF signals intelligence AI. Analyze this captured signal with precision.

        Signal: \(signal.name) (\(signal.signalType.rawValue))
        File: \(signal.path)
        Size: \(signal.size) bytes

        Analysis Type: \(analysisType.displayName)

        \(instructions)

        Structure your response with these sections:
        ## PROTOCOL IDENTIFICATION
        ## VULNERABILITIES
        ## EXPLOITS
        ## THREAT ASSESSMENT
        ## RECOMMENDATIONS

        Signal file content:
        ```
        \(truncatedContent)
        ```

        Be specific, technical, and actionable. Rate confidence levels honestly.
        """
    }

    // MARK: - Response Parsing

    private func parseAIResponse(_ response: String, signal: SignalFile, analysisType: AnalysisType) -> OracleAnalysisResult {
        let sections = parseResponseSections(response)

        return OracleAnalysisResult(
            signalName: signal.name,
            frequency: extractFrequencyFromContent(signalContent),
            analysisType: analysisType,
            summary: extractSummary(response),
            protocolInfo: ProtocolInfo(
                name: extractProtocolName(sections["PROTOCOL IDENTIFICATION"] ?? response),
                family: extractValue(response, keywords: "family", "protocol family"),
                encoding: extractValue(response, keywords: "encoding", "modulation"),
                isEncrypted: response.localizedCaseInsensitiveContains("encrypt")
                    && !response.localizedCaseInsensitiveContains("no encrypt")
                    && !response.localizedCaseInsensitiveContains("not encrypt"),
                isRollingCode: response.localizedCaseInsensitiveContains("rolling code")
                    && !response.localizedCaseInsensitiveContains("no rolling")
                    && !response.localizedCaseInsensitiveContains("not rolling"),
                confidence: extractConfidence(response)
            ),
            vulnerabilities: parseVulnerabilities(sections["VULNERABILITIES"] ?? response),
            exploits: parseExploits(sections["EXPLOITS"] ?? sections["EXPLOIT"] ?? response),
            threatLevel: determineThreatLevel(response),
            threatAnalysis: sections["THREAT ASSESSMENT"] ?? extractSection(response, keywords: "threat", "risk"),
            recommendations: parseRecommendations(sections["RECOMMENDATIONS"] ?? response),
            rawResponse: response,
            timestamp: Date()
        )
    }

    private func parseResponseSections(_ response: String) -> [String: String] {
        var sections: [String: String] = [:]
        let sectionHeaders = [
            "PROTOCOL IDENTIFICATION", "PROTOCOL ID", "PROTOCOL ANALYSIS",
            "VULNERABILITIES", "VULNERABILITY", "SECURITY ISSUES",
            "EXPLOITS", "EXPLOIT", "ATTACK VECTORS",
            "THREAT ASSESSMENT", "THREAT ANALYSIS", "RISK ASSESSMENT",
            "RECOMMENDATIONS", "MITIGATIONS", "COUNTERMEASURES"
        ]

        var currentSection = ""
        var currentContent = ""

        for line in response.components(separatedBy: "\n") {
            let upperLine = line.uppercased()
            let headerMatch = sectionHeaders.first { header in
                upperLine.contains(header) && (line.hasPrefix("#") || line.hasPrefix("*"))
            }

            if let headerMatch {
                if !currentSection.isEmpty {
                    sections[currentSection] = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                currentSection = headerMatch
                currentContent = ""
            } else if !currentSection.isEmpty {
                currentContent += line + "\n"
            }
        }

        if !currentSection.isEmpty {
            sections[currentSection] = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return sections
    }

    private func extractSummary(_ response: String) -> String {
        let firstPara = response.components(separatedBy: "\n\n").first ?? response
        let trimmed = String(firstPara.prefix(300))
        return trimmed.count >= 300 ? trimmed + "..." : trimmed
    }

    private func extractProtocolName(_ section: String) -> String {
        let patterns = [
            "protocol[:\\s]+(\\w+)",
            "identified as[:\\s]+(\\w+)",
            "appears to be[:\\s]+(\\w+)",
            "(Princeton|KeeLoq|CAME|Nice|Chamberlain|Linear|GE|Somfy|Faac)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: section, range: NSRange(section.startIndex..., in: section)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: section) {
                return String(section[range])
            }
        }
        return "Unknown"
    }

    private func extractValue(_ text: String, keywords: String...) -> String {
        for keyword in keywords {
            let pattern = "\(keyword)[:\\s]+([^\\n,]+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown"
    }

    private func extractConfidence(_ response: String) -> Float {
        let pattern = "(\\d+)%?\\s*confidence"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: response),
           let value = Float(response[range]) {
            return min(max(value / 100.0, 0), 1)
        }

        let lower = response.lowercased()
        if lower.contains("high confidence") { return 0.85 }
        if lower.contains("moderate confidence") { return 0.65 }
        if lower.contains("low confidence") { return 0.35 }
        return 0.5
    }

    private func extractFrequencyFromContent(_ content: String?) -> String {
        guard let content else { return "Unknown" }
        let pattern = "Frequency:\\s*(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: content),
           let hz = Int64(content[range]) {
            return Self.formatFrequency(hz)
        }
        return "Unknown"
    }

    private func parseVulnerabilities(_ section: String) -> [VulnItem] {
        var vulns: [VulnItem] = []

        let severityKeywords: [(VulnerabilitySeverity, [String])] = [
            (.critical, ["critical", "severe", "dangerous"]),
            (.high, ["high", "significant", "major"]),
            (.medium, ["medium", "moderate", "notable"]),
            (.low, ["low", "minor", "minimal"]),
            (.info, ["info", "informational", "note"])
        ]

        // Parse bullet points
        let pattern = "[-*•]\\s*(.+?)(?=\\n[-*•]|\\n\\n|$)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: section, range: NSRange(section.startIndex..., in: section))
            for match in matches {
                if match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: section) {
                    let item = String(section[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if item.count > 10 {
                        var severity: VulnerabilitySeverity = .medium
                        let lowerItem = item.lowercased()
                        for (sev, keywords) in severityKeywords {
                            if keywords.contains(where: { lowerItem.contains($0) }) {
                                severity = sev
                                break
                            }
                        }

                        let name = item.count >= 60 ? String(item.prefix(60)) + "..." : item
                        vulns.append(VulnItem(name: name, description: item, severity: severity))
                    }
                }
            }
        }

        // Deduplicate by name and limit
        var seen = Set<String>()
        vulns = vulns.filter { seen.insert($0.name).inserted }
        return Array(vulns.prefix(10))
    }

    private func parseExploits(_ section: String) -> [ExploitItem] {
        var exploits: [ExploitItem] = []

        let exploitPatterns: [(String, String)] = [
            ("replay attack", "Replay Attack"),
            ("brute force", "Brute Force"),
            ("jamming", "Jamming"),
            ("code grab", "Code Grab"),
            ("timing attack", "Timing Attack"),
            ("rolljam", "RollJam"),
        ]

        let lowerSection = section.lowercased()

        for (pattern, name) in exploitPatterns {
            if lowerSection.contains(pattern) {
                // Extract surrounding context
                if let range = lowerSection.range(of: pattern) {
                    let startIdx = section.index(range.lowerBound, offsetBy: -min(100, section.distance(from: section.startIndex, to: range.lowerBound)), limitedBy: section.startIndex) ?? section.startIndex
                    let endIdx = section.index(range.upperBound, offsetBy: min(200, section.distance(from: range.upperBound, to: section.endIndex)), limitedBy: section.endIndex) ?? section.endIndex
                    let context = String(section[startIdx..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)

                    let difficulty: String
                    let lowerContext = context.lowercased()
                    if lowerContext.contains("trivial") || lowerContext.contains("easy") {
                        difficulty = "Easy"
                    } else if lowerContext.contains("complex") || lowerContext.contains("difficult") {
                        difficulty = "Hard"
                    } else {
                        difficulty = "Moderate"
                    }

                    exploits.append(ExploitItem(name: name, description: context, difficulty: difficulty))
                }
            }
        }

        var seen = Set<String>()
        exploits = exploits.filter { seen.insert($0.name).inserted }
        return Array(exploits.prefix(5))
    }

    private func determineThreatLevel(_ response: String) -> OracleRiskLevel {
        let lower = response.lowercased()
        if lower.contains("critical") && (lower.contains("vuln") || lower.contains("risk")) {
            return .critical
        }
        if lower.contains("high risk") || lower.contains("highly vulnerable") {
            return .high
        }
        if lower.contains("elevated") || lower.contains("significant risk") {
            return .elevated
        }
        if lower.contains("moderate") && lower.contains("risk") {
            return .moderate
        }
        if lower.contains("low risk") || lower.contains("minimal") {
            return .low
        }
        if lower.contains("secure") || lower.contains("protected") {
            return .minimal
        }
        return .moderate
    }

    private func extractSection(_ text: String, keywords: String...) -> String {
        for keyword in keywords {
            let pattern = "\(keyword)[:\\s]*([^#*]+?)(?=\\n#|\\n\\*\\*|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if value.count > 20 { return value }
            }
        }
        return "Analysis not available"
    }

    private func parseRecommendations(_ section: String) -> [String] {
        var recs: [String] = []
        let pattern = "[-*•\\d.]\\s*(.+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            for line in section.components(separatedBy: "\n") {
                let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
                for match in matches {
                    if match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: line) {
                        let rec = String(line[range]).trimmingCharacters(in: .whitespaces)
                        if rec.count > 10 && !rec.hasPrefix("#") {
                            recs.append(rec)
                        }
                    }
                }
            }
        }
        return Array(recs.prefix(8))
    }

    // MARK: - Actions

    func clearError() {
        error = nil
    }

    func clearResult() {
        analysisResult = nil
    }

    func setAnalysisType(_ type: AnalysisType) {
        selectedAnalysisType = type
    }

    // MARK: - Helpers

    static func formatFrequency(_ hz: Int64) -> String {
        if hz >= 1_000_000_000 {
            return String(format: "%.3f GHz", Double(hz) / 1_000_000_000.0)
        } else if hz >= 1_000_000 {
            return String(format: "%.3f MHz", Double(hz) / 1_000_000.0)
        } else if hz >= 1_000 {
            return String(format: "%.3f kHz", Double(hz) / 1_000.0)
        }
        return "\(hz) Hz"
    }

    static func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }
}

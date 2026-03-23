import SwiftUI

// MARK: - Loot Card Model

struct LootCard: Identifiable, Equatable {
    let id: String
    let name: String
    let fileName: String
    let path: String
    let signalType: SignalType
    let rarity: LootRarity
    let size: Int64
    let capturedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        fileName: String,
        path: String,
        signalType: SignalType,
        rarity: LootRarity,
        size: Int64,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.path = path
        self.signalType = signalType
        self.rarity = rarity
        self.size = size
        self.capturedAt = capturedAt
    }
}

// MARK: - Signal Type

enum SignalType: String, CaseIterable, Identifiable {
    case subGhz = "Sub-GHz"
    case ir = "IR"
    case nfc = "NFC"
    case rfid = "RFID"
    case iButton = "iButton"
    case badusb = "BadUSB"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .subGhz: "sub"
        case .ir: "ir"
        case .nfc: "nfc"
        case .rfid: "rfid"
        case .iButton: "ibtn"
        case .badusb: "txt"
        }
    }

    var flipperDirectory: String {
        switch self {
        case .subGhz: "/ext/subghz"
        case .ir: "/ext/infrared"
        case .nfc: "/ext/nfc"
        case .rfid: "/ext/lfrfid"
        case .iButton: "/ext/ibutton"
        case .badusb: "/ext/badusb"
        }
    }

    var icon: String {
        switch self {
        case .subGhz: "antenna.radiowaves.left.and.right"
        case .ir: "dot.radiowaves.right"
        case .nfc: "wave.3.right"
        case .rfid: "sensor.tag.radiowaves.forward"
        case .iButton: "key.fill"
        case .badusb: "keyboard"
        }
    }

    var payloadEngineType: String {
        switch self {
        case .subGhz: "subghz"
        case .ir: "ir"
        case .nfc: "nfc"
        case .rfid: "rfid"
        case .iButton: "ibutton"
        case .badusb: "badusb"
        }
    }

    /// Detect signal type from a file name or path
    static func detect(from fileName: String, in directory: String) -> SignalType {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "sub": return .subGhz
        case "ir": return .ir
        case "nfc": return .nfc
        case "rfid": return .rfid
        case "ibtn": return .iButton
        case "txt" where directory.contains("badusb"): return .badusb
        default: break
        }
        // Fallback: infer from directory path
        if directory.contains("subghz") { return .subGhz }
        if directory.contains("infrared") { return .ir }
        if directory.contains("nfc") { return .nfc }
        if directory.contains("lfrfid") { return .rfid }
        if directory.contains("ibutton") { return .iButton }
        if directory.contains("badusb") { return .badusb }
        return .subGhz
    }
}

// MARK: - Loot Rarity

enum LootRarity: String, CaseIterable {
    case common
    case uncommon
    case rare
    case legendary

    var color: Color {
        switch self {
        case .common: .gray
        case .uncommon: .green
        case .rare: .blue
        case .legendary: .purple
        }
    }

    var label: String { rawValue.capitalized }

    /// Classify rarity based on file size
    static func classify(size: Int64) -> LootRarity {
        switch size {
        case ..<1024: return .common          // < 1KB
        case 1024..<10240: return .uncommon   // 1-10KB
        case 10240..<102400: return .rare     // 10-100KB
        default: return .legendary            // > 100KB
        }
    }
}

// MARK: - Active Tab

enum AlchemyTab: String, CaseIterable {
    case forge = "Forge"
    case vault = "Vault"
    case workbench = "Workbench"

    var icon: String {
        switch self {
        case .forge: "flame.fill"
        case .vault: "archivebox.fill"
        case .workbench: "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - View Model

@Observable
class AlchemyLabViewModel {
    private let payloadEngine: PayloadEngine
    private let fileSystem: FlipperFileSystemProtocol
    private let commandExecutor: CommandExecuting

    // ── Active Tab ──────────────────────────────────────────
    var activeTab: AlchemyTab = .forge

    // ── Forge State ─────────────────────────────────────────
    var forgePrompt: String = ""
    var forgeSignalType: SignalType = .subGhz
    var isForging: Bool = false
    var forgedContent: String?
    var forgedFileName: String?
    var forgeError: String?
    var isDeploying: Bool = false
    var deployMessage: String?
    var forgeHistory: [ForgeHistoryEntry] = []

    // ── Vault State ─────────────────────────────────────────
    var lootCards: [LootCard] = []
    var isLoadingVault: Bool = false
    var vaultError: String?
    var vaultFilterType: SignalType?
    var vaultSearchQuery: String = ""
    var isDeleting: Bool = false

    // ── Workbench State ─────────────────────────────────────
    var workbenchPath: String?
    var workbenchContent: String = ""
    var isLoadingWorkbench: Bool = false
    var isSavingWorkbench: Bool = false
    var workbenchError: String?
    var workbenchMessage: String?

    // ── General ─────────────────────────────────────────────
    var message: String?

    // ── Computed ─────────────────────────────────────────────

    var filteredLootCards: [LootCard] {
        var cards = lootCards
        if let filter = vaultFilterType {
            cards = cards.filter { $0.signalType == filter }
        }
        if !vaultSearchQuery.isEmpty {
            let query = vaultSearchQuery.lowercased()
            cards = cards.filter {
                $0.name.lowercased().contains(query) ||
                $0.fileName.lowercased().contains(query) ||
                $0.path.lowercased().contains(query)
            }
        }
        return cards
    }

    var vaultStats: [SignalType: Int] {
        Dictionary(grouping: lootCards, by: \.signalType).mapValues(\.count)
    }

    // ── Init ────────────────────────────────────────────────

    init(
        payloadEngine: PayloadEngine,
        fileSystem: FlipperFileSystemProtocol,
        commandExecutor: CommandExecuting
    ) {
        self.payloadEngine = payloadEngine
        self.fileSystem = fileSystem
        self.commandExecutor = commandExecutor
    }

    // ═══════════════════════════════════════════════════════
    // FORGE ACTIONS
    // ═══════════════════════════════════════════════════════

    func forge() {
        let prompt = forgePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        isForging = true
        forgeError = nil
        forgedContent = nil
        forgedFileName = nil
        deployMessage = nil

        Task {
            do {
                let payload = try await payloadEngine.generatePayload(
                    type: forgeSignalType.payloadEngineType,
                    prompt: prompt
                )
                forgedContent = payload.content
                forgedFileName = payload.filename

                // Add to history
                let entry = ForgeHistoryEntry(
                    prompt: prompt,
                    signalType: forgeSignalType,
                    fileName: payload.filename,
                    content: payload.content
                )
                forgeHistory.insert(entry, at: 0)
                if forgeHistory.count > 10 {
                    forgeHistory = Array(forgeHistory.prefix(10))
                }
            } catch {
                forgeError = error.localizedDescription
            }
            isForging = false
        }
    }

    func deployForgedSignal() {
        guard let content = forgedContent else { return }
        let fileName = forgedFileName ?? "vesper_forged.\(forgeSignalType.fileExtension)"
        let dirPath = forgeSignalType.flipperDirectory
        let fullPath = "\(dirPath)/\(fileName)"

        isDeploying = true
        deployMessage = nil
        forgeError = nil

        Task {
            do {
                // Ensure parent directory exists
                try await fileSystem.createDirectory(dirPath)

                // Write the file
                _ = try await fileSystem.writeFile(fullPath, content: content)
                deployMessage = "Deployed to \(fullPath)"

                // Refresh vault if it was loaded
                if !lootCards.isEmpty {
                    loadVault()
                }
            } catch {
                forgeError = "Deploy failed: \(error.localizedDescription)"
            }
            isDeploying = false
        }
    }

    func clearForge() {
        forgePrompt = ""
        forgedContent = nil
        forgedFileName = nil
        forgeError = nil
        deployMessage = nil
    }

    func loadFromHistory(_ entry: ForgeHistoryEntry) {
        forgePrompt = entry.prompt
        forgeSignalType = entry.signalType
        forgedContent = entry.content
        forgedFileName = entry.fileName
        deployMessage = nil
        forgeError = nil
    }

    // ═══════════════════════════════════════════════════════
    // VAULT ACTIONS
    // ═══════════════════════════════════════════════════════

    func loadVault() {
        isLoadingVault = true
        vaultError = nil

        let scanDirs: [(String, SignalType)] = [
            ("/ext/subghz", .subGhz),
            ("/ext/infrared", .ir),
            ("/ext/nfc", .nfc),
            ("/ext/lfrfid", .rfid),
            ("/ext/ibutton", .iButton),
            ("/ext/badusb", .badusb),
        ]

        Task {
            var allLoot: [LootCard] = []

            await withTaskGroup(of: [LootCard].self) { group in
                for (dir, expectedType) in scanDirs {
                    group.addTask { [fileSystem] in
                        do {
                            let entries = try await fileSystem.listDirectory(dir)
                            return entries
                                .filter { !$0.isDirectory }
                                .map { entry in
                                    let detectedType = SignalType.detect(from: entry.name, in: dir)
                                    let finalType = (detectedType == .subGhz && dir != "/ext/subghz") ? expectedType : detectedType

                                    return LootCard(
                                        name: (entry.name as NSString).deletingPathExtension,
                                        fileName: entry.name,
                                        path: entry.path,
                                        signalType: finalType,
                                        rarity: LootRarity.classify(size: entry.size),
                                        size: entry.size,
                                        capturedAt: entry.modifiedTimestamp.map {
                                            Date(timeIntervalSince1970: TimeInterval($0))
                                        } ?? Date()
                                    )
                                }
                        } catch {
                            return []
                        }
                    }
                }

                for await lootBatch in group {
                    allLoot.append(contentsOf: lootBatch)
                }
            }

            lootCards = allLoot.sorted { $0.capturedAt > $1.capturedAt }
            isLoadingVault = false
        }
    }

    func deleteFromVault(_ card: LootCard) {
        isDeleting = true

        Task {
            do {
                try await fileSystem.delete(card.path, recursive: false)
                lootCards.removeAll { $0.id == card.id }
                message = "Deleted \(card.name)"
            } catch {
                message = "Delete failed: \(error.localizedDescription)"
            }
            isDeleting = false
        }
    }

    func setVaultFilter(_ type: SignalType?) {
        vaultFilterType = (vaultFilterType == type) ? nil : type
    }

    // ═══════════════════════════════════════════════════════
    // WORKBENCH ACTIONS
    // ═══════════════════════════════════════════════════════

    func openInWorkbench(card: LootCard) {
        openInWorkbench(path: card.path)
    }

    func openInWorkbench(path: String) {
        workbenchPath = path
        workbenchContent = ""
        workbenchError = nil
        workbenchMessage = nil
        isLoadingWorkbench = true
        activeTab = .workbench

        Task {
            do {
                let content = try await fileSystem.readFile(path)
                workbenchContent = content
            } catch {
                workbenchError = "Failed to read file: \(error.localizedDescription)"
            }
            isLoadingWorkbench = false
        }
    }

    func saveWorkbench() {
        guard let path = workbenchPath else { return }
        isSavingWorkbench = true
        workbenchError = nil
        workbenchMessage = nil

        Task {
            do {
                _ = try await fileSystem.writeFile(path, content: workbenchContent)
                workbenchMessage = "Saved to \(path)"
            } catch {
                workbenchError = "Save failed: \(error.localizedDescription)"
            }
            isSavingWorkbench = false
        }
    }

    func closeWorkbench() {
        workbenchPath = nil
        workbenchContent = ""
        workbenchError = nil
        workbenchMessage = nil
    }

    func openForgedInWorkbench() {
        guard let content = forgedContent else { return }
        let fileName = forgedFileName ?? "forged.\(forgeSignalType.fileExtension)"
        let path = "\(forgeSignalType.flipperDirectory)/\(fileName)"
        workbenchPath = path
        workbenchContent = content
        workbenchError = nil
        workbenchMessage = nil
        activeTab = .workbench
    }

    // ═══════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════

    func clearMessage() {
        message = nil
    }

    static func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }
}

// MARK: - Forge History Entry

struct ForgeHistoryEntry: Identifiable {
    let id = UUID().uuidString
    let prompt: String
    let signalType: SignalType
    let fileName: String
    let content: String
    let timestamp = Date()
}

// CommandExecuting protocol is defined in VesperAgent.swift
// CommandExecutor already conforms to it

// ═══════════════════════════════════════════════════════════
// VIEWS
// ═══════════════════════════════════════════════════════════

// MARK: - Main View

struct AlchemyLabView: View {
    @Bindable var viewModel: AlchemyLabViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $viewModel.activeTab) {
                ForEach(AlchemyTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Tab content
            switch viewModel.activeTab {
            case .forge:
                ForgeTabView(viewModel: viewModel)
            case .vault:
                VaultTabView(viewModel: viewModel)
            case .workbench:
                WorkbenchTabView(viewModel: viewModel)
            }
        }
        .navigationTitle("Alchemy Lab")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let msg = viewModel.message {
                Text(msg)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            viewModel.clearMessage()
                        }
                    }
            }
        }
        .animation(.easeInOut, value: viewModel.message)
    }
}

// MARK: - Forge Tab

struct ForgeTabView: View {
    @Bindable var viewModel: AlchemyLabViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Signal type picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signal Type")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SignalType.allCases) { type in
                                Button {
                                    viewModel.forgeSignalType = type
                                } label: {
                                    Label(type.rawValue, systemImage: type.icon)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            viewModel.forgeSignalType == type
                                                ? Color.accentColor
                                                : Color(.systemGray5)
                                        )
                                        .foregroundStyle(
                                            viewModel.forgeSignalType == type
                                                ? .white
                                                : .primary
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Prompt input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField(
                        "Describe the signal to forge...",
                        text: $viewModel.forgePrompt,
                        axis: .vertical
                    )
                    .lineLimit(2...6)
                    .textFieldStyle(.roundedBorder)
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        viewModel.forge()
                    } label: {
                        HStack {
                            if viewModel.isForging {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "flame.fill")
                            }
                            Text("Forge")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(
                        viewModel.isForging ||
                        viewModel.forgePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    if viewModel.forgedContent != nil {
                        Button {
                            viewModel.clearForge()
                        } label: {
                            Image(systemName: "xmark")
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Error
                if let error = viewModel.forgeError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Generated preview
                if let content = viewModel.forgedContent {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Generated: \(viewModel.forgedFileName ?? "signal")")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                UIPasteboard.general.string = content
                                viewModel.message = "Copied to clipboard"
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        ScrollView {
                            Text(content)
                                .font(.system(.caption2, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 200)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        HStack(spacing: 12) {
                            Button {
                                viewModel.deployForgedSignal()
                            } label: {
                                HStack {
                                    if viewModel.isDeploying {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    Text("Deploy to Flipper")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isDeploying)

                            Button {
                                viewModel.openForgedInWorkbench()
                            } label: {
                                Image(systemName: "wrench.and.screwdriver")
                                Text("Edit")
                            }
                            .buttonStyle(.bordered)
                        }

                        if let deployMsg = viewModel.deployMessage {
                            Label(deployMsg, systemImage: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Forge history
                if !viewModel.forgeHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("History")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(viewModel.forgeHistory) { entry in
                            Button {
                                viewModel.loadFromHistory(entry)
                            } label: {
                                HStack {
                                    Image(systemName: entry.signalType.icon)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.prompt)
                                            .font(.footnote)
                                            .lineLimit(1)
                                            .foregroundStyle(.primary)
                                        Text(entry.fileName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Vault Tab

struct VaultTabView: View {
    @Bindable var viewModel: AlchemyLabViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        label: "All",
                        count: viewModel.lootCards.count,
                        isSelected: viewModel.vaultFilterType == nil
                    ) {
                        viewModel.setVaultFilter(nil)
                    }

                    ForEach(SignalType.allCases) { type in
                        let count = viewModel.vaultStats[type] ?? 0
                        if count > 0 {
                            FilterChip(
                                label: type.rawValue,
                                icon: type.icon,
                                count: count,
                                isSelected: viewModel.vaultFilterType == type
                            ) {
                                viewModel.setVaultFilter(type)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search vault...", text: $viewModel.vaultSearchQuery)
                    .textFieldStyle(.plain)
                if !viewModel.vaultSearchQuery.isEmpty {
                    Button {
                        viewModel.vaultSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Content
            if viewModel.isLoadingVault {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning Flipper vault...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.filteredLootCards.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(viewModel.lootCards.isEmpty ? "Vault is empty" : "No matches")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if viewModel.lootCards.isEmpty {
                        Text("Connect to Flipper and scan to populate")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredLootCards) { card in
                        LootCardRow(card: card)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteFromVault(card)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    viewModel.openInWorkbench(card: card)
                                } label: {
                                    Label("Edit", systemImage: "wrench")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
            }

            if let error = viewModel.vaultError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
        .onAppear {
            if viewModel.lootCards.isEmpty {
                viewModel.loadVault()
            }
        }
        .refreshable {
            viewModel.loadVault()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.loadVault()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingVault)
            }
        }
    }
}

// MARK: - Loot Card Row

struct LootCardRow: View {
    let card: LootCard

    var body: some View {
        HStack(spacing: 12) {
            // Rarity indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(card.rarity.color)
                .frame(width: 4, height: 44)

            // Icon
            Image(systemName: card.signalType.icon)
                .font(.title3)
                .foregroundStyle(card.rarity.color)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(card.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(card.signalType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())

                    Text(card.rarity.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(card.rarity.color)

                    Text(AlchemyLabViewModel.formatFileSize(card.size))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    var icon: String?
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption.weight(.medium))
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workbench Tab

struct WorkbenchTabView: View {
    @Bindable var viewModel: AlchemyLabViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let path = viewModel.workbenchPath {
                // File path header
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(path)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        viewModel.closeWorkbench()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))

                if viewModel.isLoadingWorkbench {
                    Spacer()
                    ProgressView("Loading file...")
                    Spacer()
                } else {
                    // Editor
                    TextEditor(text: $viewModel.workbenchContent)
                        .font(.system(.caption, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(4)

                    // Action bar
                    HStack(spacing: 12) {
                        if let error = viewModel.workbenchError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        } else if let msg = viewModel.workbenchMessage {
                            Label(msg, systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            viewModel.saveWorkbench()
                        } label: {
                            HStack(spacing: 4) {
                                if viewModel.isSavingWorkbench {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                }
                                Text("Save")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(viewModel.isSavingWorkbench)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
            } else {
                // Empty state
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No file open")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Open a file from the Vault or forge a new signal to edit it here.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Waveform Editor (preserved from original)

struct SignalEditorView: View {
    @Binding var signalData: String

    var body: some View {
        VStack(spacing: 0) {
            Text("Signal Waveform Editor")
                .font(.headline)
                .padding()

            // Visual waveform representation
            GeometryReader { geometry in
                Canvas { context, size in
                    let values = signalData.split(separator: " ").compactMap { Int($0) }
                    guard !values.isEmpty else { return }

                    let maxAbs = Double(values.map { abs($0) }.max() ?? 1)
                    let midY = size.height / 2
                    let stepWidth = size.width / Double(values.count)

                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: midY))

                    for (index, value) in values.enumerated() {
                        let x = Double(index) * stepWidth
                        let y = midY - (Double(value) / maxAbs) * (midY * 0.8)
                        path.addLine(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + stepWidth, y: y))
                    }

                    context.stroke(path, with: .color(.green), lineWidth: 2)

                    // Center line
                    var centerLine = Path()
                    centerLine.move(to: CGPoint(x: 0, y: midY))
                    centerLine.addLine(to: CGPoint(x: size.width, y: midY))
                    context.stroke(centerLine, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                }
            }
            .frame(height: 150)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()

            TextEditor(text: $signalData)
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .padding(.horizontal)
        }
    }
}

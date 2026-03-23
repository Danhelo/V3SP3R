import SwiftUI

struct PayloadLabView: View {
    @Bindable var viewModel: PayloadLabViewModel

    var body: some View {
        Form {
            // Tab Picker
            Section {
                Picker("Mode", selection: $viewModel.selectedTab) {
                    ForEach(PayloadLabTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Phase Indicator
            if viewModel.phase != .idle {
                phaseIndicator
            }

            // Tab Content
            switch viewModel.selectedTab {
            case .badusb:
                badUsbSection
            case .evilPortal:
                evilPortalSection
            case .quickActions:
                quickActionsSection
            }

            // Success Message
            if let success = viewModel.successMessage {
                Section {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            // Error Message
            if let error = viewModel.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Payload Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Phase Indicator

    private var phaseIndicator: some View {
        Section {
            HStack(spacing: 12) {
                phaseIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(phaseTitle)
                        .font(.subheadline.bold())
                    if !viewModel.phaseMessage.isEmpty {
                        Text(viewModel.phaseMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if case .generating = viewModel.phase {
                    ProgressView().controlSize(.small)
                } else if case .executing = viewModel.phase {
                    ProgressView().controlSize(.small)
                } else if case .validating = viewModel.phase {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var phaseIcon: some View {
        switch viewModel.phase {
        case .idle:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .generating:
            Image(systemName: "sparkles").foregroundStyle(.purple)
        case .validating:
            Image(systemName: "checkmark.shield").foregroundStyle(.orange)
        case .ready:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .executing:
            Image(systemName: "bolt.fill").foregroundStyle(.blue)
        case .complete:
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private var phaseTitle: String {
        switch viewModel.phase {
        case .idle: return "Ready"
        case .generating: return "Generating"
        case .validating: return "Validating"
        case .ready: return "Ready"
        case .executing: return "Executing"
        case .complete: return "Complete"
        case .error(let msg): return "Error: \(msg.prefix(50))"
        }
    }

    // MARK: - BadUSB Section

    @ViewBuilder
    private var badUsbSection: some View {
        // Template Picker
        Section("Templates") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BadUsbTemplate.allTemplates) { template in
                        Button {
                            viewModel.loadTemplate(template)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: template.id == "custom" ? "wand.and.stars" : "doc.text")
                                    .font(.title3)
                                Text(template.name)
                                    .font(.caption2)
                            }
                            .frame(width: 80)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedTemplate?.id == template.id
                                    ? Color.accentColor.opacity(0.2)
                                    : Color(.systemGray6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        viewModel.selectedTemplate?.id == template.id
                                            ? Color.accentColor
                                            : .clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .tint(.primary)
                    }
                }
            }
        }

        // Prompt
        Section("Describe Your Script") {
            TextField("e.g., Open terminal and run a command...", text: $viewModel.badUsbPrompt, axis: .vertical)
                .lineLimit(3...6)
        }

        // Generate Button
        Section {
            Button {
                viewModel.generateBadUsbScript(prompt: viewModel.badUsbPrompt)
            } label: {
                HStack {
                    if case .generating = viewModel.phase {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(viewModel.phase == .generating ? "Generating..." : "Generate Script")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.phase == .generating || viewModel.badUsbPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        // Script Preview
        if let script = viewModel.generatedScript {
            Section("Generated Script") {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        Text(script)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Script name input
                    HStack {
                        Text("Name:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("payload", text: $viewModel.scriptName)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            viewModel.saveBadUsbScript()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.phase == .executing)

                        Button {
                            viewModel.executeBadUsb()
                        } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Execute")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(viewModel.phase == .executing)
                    }
                }
            }
        }
    }

    // MARK: - Evil Portal Section

    @ViewBuilder
    private var evilPortalSection: some View {
        // Portal Type Picker
        Section("Portal Type") {
            Picker("Type", selection: $viewModel.selectedPortalType) {
                ForEach(EvilPortalType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }

        // Prompt (optional - for AI customization)
        Section("Customize (optional)") {
            TextField("e.g., Make it look like a coffee shop WiFi...", text: $viewModel.portalPrompt, axis: .vertical)
                .lineLimit(2...4)
        }

        // Generate Button
        Section {
            Button {
                viewModel.generateEvilPortal(type: viewModel.selectedPortalType)
            } label: {
                HStack {
                    if case .generating = viewModel.phase {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "globe")
                    }
                    Text(viewModel.phase == .generating ? "Generating..." : "Generate Portal")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.phase == .generating)
        }

        // HTML Preview
        if let html = viewModel.generatedHTML {
            Section("Generated Portal") {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        Text(html)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Portal name input
                    HStack {
                        Text("Name:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("portal", text: $viewModel.portalName)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                    }

                    // Deploy button
                    Button {
                        viewModel.deployEvilPortal()
                    } label: {
                        HStack {
                            if case .executing = viewModel.phase {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.up.doc.fill")
                            }
                            Text(viewModel.phase == .executing ? "Deploying..." : "Deploy to Flipper")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(viewModel.phase == .executing)
                }
            }
        }
    }

    // MARK: - Quick Actions Section

    @ViewBuilder
    private var quickActionsSection: some View {
        // Sub-GHz Transmit
        Section("Sub-GHz Transmit") {
            TextField("/ext/subghz/signal.sub", text: $viewModel.quickActionPath)
                .font(.caption.monospaced())
                .textFieldStyle(.roundedBorder)

            Button {
                viewModel.transmitSubGhz(path: viewModel.quickActionPath)
            } label: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Transmit Sub-GHz")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.quickActionPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isExecuting)
        }

        // IR Transmit
        Section("IR Transmit") {
            TextField("/ext/infrared/remote.ir", text: $viewModel.quickActionPath)
                .font(.caption.monospaced())
                .textFieldStyle(.roundedBorder)

            TextField("Signal name (optional)", text: $viewModel.quickActionSignalName)
                .font(.caption)
                .textFieldStyle(.roundedBorder)

            Button {
                viewModel.transmitIR(
                    path: viewModel.quickActionPath,
                    signalName: viewModel.quickActionSignalName.isEmpty ? nil : viewModel.quickActionSignalName
                )
            } label: {
                HStack {
                    Image(systemName: "dot.radiowaves.right")
                    Text("Transmit IR")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.quickActionPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isExecuting)
        }

        // BLE Spam
        Section("BLE Spam") {
            let protocols = ["apple_ble", "samsung_ble", "windows_ble", "google_ble", "all"]
            Picker("Protocol", selection: $viewModel.quickActionProtocol) {
                ForEach(protocols, id: \.self) { proto in
                    Text(proto).tag(proto)
                }
            }

            Button {
                viewModel.startBleSpam(protocol: viewModel.quickActionProtocol)
            } label: {
                HStack {
                    Image(systemName: "wave.3.right")
                    Text("Start BLE Spam")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(viewModel.isExecuting)
        }

        // CLI Command
        Section("Raw CLI") {
            TextField("e.g., led r 255 0 0", text: $viewModel.quickActionCliCommand)
                .font(.caption.monospaced())
                .textFieldStyle(.roundedBorder)

            Button {
                viewModel.executeCliCommand(command: viewModel.quickActionCliCommand)
            } label: {
                HStack {
                    Image(systemName: "terminal")
                    Text("Execute CLI")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.quickActionCliCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isExecuting)
        }

        if viewModel.isExecuting {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Executing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

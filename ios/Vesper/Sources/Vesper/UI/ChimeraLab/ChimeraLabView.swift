// ChimeraLabView.swift
// Vesper - AI-powered Flipper Zero controller
// RF Chimera - Signal Fusion Laboratory UI

import SwiftUI

struct ChimeraLabView: View {
    @Bindable var viewModel: ChimeraLabViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Source signals section
                sourceSignalsSection

                // Mutation mode picker
                mutationModeSection

                // Output signal type
                outputTypeSection

                // Synthesize button
                synthesizeSection

                // Chimera preview
                if let output = viewModel.chimeraOutput {
                    chimeraPreviewSection(output: output)
                }

                // Export + Transmit
                if viewModel.chimeraOutput != nil {
                    exportSection
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Chimera Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "")
        }
        .alert("Success", isPresented: .init(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.clearSuccess() } }
        )) {
            Button("OK") { viewModel.clearSuccess() }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    // MARK: - Source Signals Section

    private var sourceSignalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Source Signals (\(viewModel.sourceSignals.count))", systemImage: "waveform")
                .font(.headline)

            // Add signal input
            HStack {
                TextField("Signal file path (e.g. /ext/subghz/remote.sub)", text: $viewModel.signalLoadPath)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    viewModel.loadSourceSignal(path: viewModel.signalLoadPath)
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.signalLoadPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Source signals list
            if viewModel.sourceSignals.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Add 2+ signals to begin fusion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(viewModel.sourceSignals) { signal in
                    SourceSignalCard(signal: signal) {
                        viewModel.removeSourceSignal(id: signal.id)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Mutation Mode Section

    private var mutationModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Mutation Mode", systemImage: "circle.hexagongrid")
                .font(.headline)

            ForEach(MutationMode.allCases) { mode in
                Button {
                    viewModel.selectedMutationMode = mode
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.systemImage)
                            .font(.title3)
                            .frame(width: 28)
                            .foregroundStyle(viewModel.selectedMutationMode == mode ? .white : .purple)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .font(.subheadline.bold())
                            Text(mode.description)
                                .font(.caption)
                                .lineLimit(2)
                        }
                        .foregroundStyle(viewModel.selectedMutationMode == mode ? .white : .primary)

                        Spacer()

                        if viewModel.selectedMutationMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(10)
                    .background(viewModel.selectedMutationMode == mode ? Color.purple : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Output Type Section

    private var outputTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Output Type", systemImage: "square.and.arrow.up")
                .font(.headline)

            Picker("Signal Type", selection: $viewModel.outputSignalType) {
                ForEach(ChimeraSignalType.allCases) { type in
                    Label(type.rawValue, systemImage: type.systemImage)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Synthesize Section

    private var synthesizeSection: some View {
        Button {
            viewModel.synthesize()
        } label: {
            HStack {
                if viewModel.isSynthesizing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text(viewModel.isSynthesizing ? "Synthesizing..." : "Synthesize Chimera")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.sourceSignals.count >= 2 ? Color.purple : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(viewModel.sourceSignals.count < 2 || viewModel.isSynthesizing)
    }

    // MARK: - Chimera Preview Section

    private func chimeraPreviewSection(output: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Chimera Output", systemImage: "doc.text")
                .font(.headline)

            ScrollView(.vertical) {
                Text(output)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export & Transmit", systemImage: "square.and.arrow.up.on.square")
                .font(.headline)

            // Name input
            HStack {
                Text("Name:")
                    .font(.subheadline)
                TextField("chimera", text: $viewModel.chimeraName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            // Path input
            HStack {
                Text("Path:")
                    .font(.subheadline)
                TextField("/ext/subghz", text: $viewModel.exportPath)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            // Action buttons
            HStack(spacing: 12) {
                // Export button
                Button {
                    viewModel.exportChimera()
                } label: {
                    HStack {
                        if viewModel.isExporting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("Export")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(viewModel.isExporting)

                // Transmit button
                Button {
                    viewModel.transmitChimera()
                } label: {
                    HStack {
                        if viewModel.isTransmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text("Transmit")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(viewModel.isTransmitting)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Source Signal Card

private struct SourceSignalCard: View {
    let signal: SourceSignal
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: signal.type.systemImage)
                .font(.title3)
                .foregroundStyle(.purple)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(signal.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(signal.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(signal.type.rawValue) -- \(signal.content.count) bytes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

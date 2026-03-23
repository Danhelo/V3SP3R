// SpectralOracleView.swift
// Vesper - AI-powered Flipper Zero controller
// AI Signal Intelligence UI - ported from Android SpectralOracleScreen

import SwiftUI

// MARK: - Main View

struct SpectralOracleView: View {
    @Bindable var viewModel: SpectralOracleViewModel
    @State private var showSignalPicker = false

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.1, green: 0.05, blue: 0.18),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    oracleHeader

                    // Signal selector
                    signalSelector

                    // Analysis type picker
                    analysisTypePicker

                    // Analyze button
                    analyzeButton

                    // Content area
                    if viewModel.isAnalyzing {
                        loadingState
                    } else if let result = viewModel.analysisResult {
                        analysisResultView(result)
                    } else if viewModel.selectedSignal != nil {
                        signalPreview
                    } else {
                        idleState
                    }

                    // Error banner
                    if let error = viewModel.error {
                        errorBanner(error)
                    }

                    // History section
                    if !viewModel.analysisHistory.isEmpty {
                        historySection
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Spectral Oracle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showSignalPicker) {
            signalPickerSheet
        }
        .sheet(isPresented: $viewModel.showRawResponse) {
            if let result = viewModel.analysisResult {
                rawResponseSheet(result.rawResponse)
            }
        }
        .onAppear {
            if viewModel.availableSignals.isEmpty {
                viewModel.loadAvailableSignals()
            }
        }
    }

    // MARK: - Header

    private var oracleHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SPECTRAL ORACLE")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                    .tracking(4)
                Text("AI Signal Intelligence")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0, green: 1, blue: 0.82))
            }
            Spacer()
            Text("🔮")
                .font(.system(size: 40))
        }
    }

    // MARK: - Signal Selector

    private var signalSelector: some View {
        Button {
            showSignalPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(Color.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedSignal?.name ?? "Select a signal to analyze")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if let signal = viewModel.selectedSignal {
                        Text("\(signal.signalType.rawValue) - \(SpectralOracleViewModel.formatFileSize(signal.size))")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0, green: 1, blue: 0.82))
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundStyle(.white)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Analysis Type Picker

    private var analysisTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalysisType.allCases) { type in
                    let isSelected = type == viewModel.selectedAnalysisType
                    Button {
                        viewModel.setAnalysisType(type)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.caption2)
                            Text(type.displayName)
                                .font(.caption.weight(isSelected ? .bold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.purple : Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? Color.purple : Color.purple.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Analyze Button

    private var analyzeButton: some View {
        Button {
            viewModel.analyzeSignal()
        } label: {
            HStack(spacing: 12) {
                if viewModel.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text(viewModel.analysisProgress)
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("🔮")
                        .font(.title2)
                    Text("CONSULT THE ORACLE")
                        .font(.subheadline.weight(.bold))
                        .tracking(2)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        viewModel.selectedSignal != nil && !viewModel.isAnalyzing
                            ? Color.purple
                            : Color.white.opacity(0.08)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedSignal == nil || viewModel.isAnalyzing)
    }

    // MARK: - Signal Preview

    private var signalPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoadingContent {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text("Loading signal content...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let content = viewModel.signalContent {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signal Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0, green: 1, blue: 0.82))

                    ScrollView {
                        Text(content)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)
                .tint(Color(red: 0, green: 1, blue: 0.82))

            Text("The Oracle is analyzing...")
                .font(.headline)
                .foregroundStyle(Color(red: 0, green: 1, blue: 0.82))

            Text("Decoding spectral patterns")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Idle State

    private var idleState: some View {
        VStack(spacing: 16) {
            Text("👁️")
                .font(.system(size: 64))
            Text("Select a signal to begin")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
            Text("The Oracle awaits your query")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Analysis Result

    @ViewBuilder
    private func analysisResultView(_ result: OracleAnalysisResult) -> some View {
        VStack(spacing: 12) {
            // Threat Level Card
            threatLevelCard(result)

            // Summary
            resultSection(title: "Summary", icon: "doc.text") {
                Text(result.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Vulnerabilities
            if !result.vulnerabilities.isEmpty {
                resultSection(title: "Vulnerabilities (\(result.vulnerabilities.count))", icon: "shield.lefthalf.filled") {
                    ForEach(result.vulnerabilities) { vuln in
                        vulnerabilityRow(vuln)
                    }
                }
            }

            // Exploits
            if !result.exploits.isEmpty {
                resultSection(title: "Exploit Vectors (\(result.exploits.count))", icon: "bolt.shield") {
                    ForEach(result.exploits) { exploit in
                        exploitRow(exploit)
                    }
                }
            }

            // Threat Analysis
            resultSection(title: "Threat Analysis", icon: "exclamationmark.triangle") {
                Text(result.threatAnalysis)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Recommendations
            if !result.recommendations.isEmpty {
                resultSection(title: "Recommendations", icon: "lightbulb") {
                    ForEach(Array(result.recommendations.enumerated()), id: \.offset) { index, rec in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color(red: 0, green: 1, blue: 0.82))
                                .frame(width: 24)
                            Text(rec)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
            }

            // Raw Response Button
            Button {
                viewModel.showRawResponse = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                    Text("View Raw AI Response")
                }
                .font(.subheadline)
                .foregroundStyle(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Threat Level Card

    private func threatLevelCard(_ result: OracleAnalysisResult) -> some View {
        let color = threatLevelColor(result.threatLevel)

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THREAT LEVEL")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(result.threatLevel.displayName.uppercased())
                        .font(.title2.weight(.black))
                        .foregroundStyle(color)
                }
                Spacer()
                Text(result.threatLevel.emoji)
                    .font(.system(size: 40))
            }

            Divider()
                .overlay(Color.white.opacity(0.2))

            HStack(spacing: 0) {
                protocolChip(label: "Protocol", value: result.protocolInfo.name)
                Spacer()
                protocolChip(label: "Encoding", value: result.protocolInfo.encoding)
                Spacer()
                protocolChip(
                    label: "Security",
                    value: result.protocolInfo.isEncrypted && result.protocolInfo.isRollingCode
                        ? "Strong" : result.protocolInfo.isEncrypted || result.protocolInfo.isRollingCode
                        ? "Partial" : "Weak"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 2)
                )
        )
    }

    private func protocolChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    // MARK: - Result Section

    private func resultSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(red: 0, green: 1, blue: 0.82))

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Vulnerability Row

    private func vulnerabilityRow(_ vuln: VulnItem) -> some View {
        let color = severityColor(vuln.severity)

        return HStack(alignment: .top, spacing: 12) {
            Text(vuln.severity.rawValue.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(vuln.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(vuln.description)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Exploit Row

    private func exploitRow(_ exploit: ExploitItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exploit.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)

                Spacer()

                Text(exploit.difficulty)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                    )
            }

            Text(exploit.description)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
            Spacer()
            Button {
                viewModel.clearError()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.9))
        )
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis History")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(red: 0, green: 1, blue: 0.82))

            ForEach(viewModel.analysisHistory) { entry in
                HStack(spacing: 12) {
                    Circle()
                        .fill(threatLevelColor(entry.riskLevel))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.signalName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("\(entry.analysisType.displayName) - \(entry.riskLevel.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    Text(entry.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 4)

                if entry.id != viewModel.analysisHistory.last?.id {
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Signal Picker Sheet

    private var signalPickerSheet: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingSignals {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Scanning Flipper for signals...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.availableSignals.isEmpty {
                    VStack(spacing: 16) {
                        Text("📡")
                            .font(.system(size: 48))
                        Text("No signals found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Capture signals with your Flipper first")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    signalList
                }
            }
            .navigationTitle("Select Signal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.loadAvailableSignals()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoadingSignals)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showSignalPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var signalList: some View {
        let grouped = Dictionary(grouping: viewModel.availableSignals, by: \.signalType)
        let sortedTypes = grouped.keys.sorted { $0.rawValue < $1.rawValue }

        return List {
            ForEach(sortedTypes, id: \.self) { type in
                Section(type.rawValue) {
                    ForEach(grouped[type] ?? []) { signal in
                        let isSelected = signal.id == viewModel.selectedSignal?.id
                        Button {
                            viewModel.selectSignal(signal)
                            showSignalPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: signal.signalType.icon)
                                    .foregroundStyle(isSelected ? .purple : .secondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(signal.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(SpectralOracleViewModel.formatFileSize(signal.size))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.purple)
                                }
                            }
                        }
                        .listRowBackground(
                            isSelected ? Color.purple.opacity(0.1) : Color.clear
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Raw Response Sheet

    private func rawResponseSheet(_ response: String) -> some View {
        NavigationStack {
            ScrollView {
                Text(response)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color(red: 0, green: 1, blue: 0.82))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.1))
            .navigationTitle("Raw AI Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.showRawResponse = false
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIPasteboard.general.string = response
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }

    // MARK: - Color Helpers

    private func threatLevelColor(_ level: OracleRiskLevel) -> Color {
        switch level {
        case .critical: Color.red
        case .high: Color.orange
        case .elevated: Color.yellow
        case .moderate: Color.green
        case .low: Color.green
        case .minimal: Color.blue
        }
    }

    private func severityColor(_ severity: VulnerabilitySeverity) -> Color {
        switch severity {
        case .critical: Color.red
        case .high: Color.orange
        case .medium: Color.yellow
        case .low: Color.green
        case .info: Color.blue
        }
    }
}

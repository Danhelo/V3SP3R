// SignalArsenalView.swift
// Vesper - AI-powered Flipper Zero controller
// Signal Arsenal: UI for browsing, replaying, and deleting captured signals

import SwiftUI

// MARK: - Main View

struct SignalArsenalView: View {
    @Bindable var viewModel: SignalArsenalViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Signal type picker (horizontal chips)
            signalTypePicker

            // Search bar
            searchBar

            // Content
            if viewModel.isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning \(viewModel.selectedType.rawValue) signals...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.filteredSignals.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                signalList
            }
        }
        .navigationTitle("Signal Arsenal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.loadSignals()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .overlay(alignment: .bottom) {
            toastOverlay
        }
        .animation(.easeInOut, value: viewModel.message)
        .animation(.easeInOut, value: viewModel.error)
        .onAppear {
            if viewModel.signals.isEmpty {
                viewModel.loadSignals()
                viewModel.loadAllCounts()
            }
        }
    }

    // MARK: - Signal Type Picker

    private var signalTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ArsenalSignalType.allCases) { type in
                    let count = viewModel.signalCounts[type] ?? 0
                    let isSelected = viewModel.selectedType == type

                    Button {
                        viewModel.selectType(type)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.caption2)
                            Text(type.rawValue)
                                .font(.caption.weight(.medium))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                            }
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
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search signals...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
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
    }

    // MARK: - Signal List

    private var signalList: some View {
        List {
            ForEach(viewModel.filteredSignals) { signal in
                SignalRow(signal: signal)
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.replaySignal(signal)
                        } label: {
                            Label(signal.type.replayVerb, systemImage: "play.fill")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteSignal(signal)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .refreshable {
            viewModel.loadSignals()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.signals.isEmpty
                  ? "antenna.radiowaves.left.and.right.slash"
                  : "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(viewModel.signals.isEmpty
                 ? "No \(viewModel.selectedType.rawValue) signals"
                 : "No matches")
                .font(.headline)
                .foregroundStyle(.secondary)

            if viewModel.signals.isEmpty {
                Text("Connect to Flipper and capture some signals, or switch to another type.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if let error = viewModel.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Toast Overlay

    @ViewBuilder
    private var toastOverlay: some View {
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

        if let error = viewModel.error, viewModel.message == nil {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.red.opacity(0.85), in: Capsule())
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        viewModel.clearError()
                    }
                }
        }
    }
}

// MARK: - Signal Row

struct SignalRow: View {
    let signal: SignalEntry

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: signal.type.icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(signal.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(signal.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())

                    Text(SignalArsenalViewModel.formatFileSize(signal.size))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(signal.fileName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Replay hint
            Image(systemName: "play.circle")
                .font(.title3)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

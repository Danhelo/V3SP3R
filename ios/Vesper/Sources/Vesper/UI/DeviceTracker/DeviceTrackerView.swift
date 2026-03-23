// DeviceTrackerView.swift
// Vesper - AI-powered Flipper Zero controller
// BLE device tracker UI

import SwiftUI

struct DeviceTrackerView: View {
    @Bindable var viewModel: DeviceTrackerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header stats
            headerView

            // Search + controls
            controlsView

            // Device list
            if viewModel.filteredDevices.isEmpty {
                emptyStateView
            } else {
                deviceListView
            }
        }
        .navigationTitle("Device Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if viewModel.isTracking {
                        viewModel.stopTracking()
                    } else {
                        viewModel.startTracking()
                    }
                } label: {
                    Image(systemName: viewModel.isTracking ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundStyle(viewModel.isTracking ? .red : .green)
                }
            }
        }
        .sheet(item: $viewModel.selectedDevice) { device in
            DeviceDetailSheet(device: device, viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            StatBadge(
                label: "Total",
                value: "\(viewModel.totalDeviceCount)",
                color: .blue
            )
            StatBadge(
                label: "Visible",
                value: "\(viewModel.deviceCount)",
                color: .green
            )
            StatBadge(
                label: "Status",
                value: viewModel.isTracking ? "Scanning" : "Idle",
                color: viewModel.isTracking ? .orange : .gray
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search devices...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Sort + hidden toggle
            HStack {
                Picker("Sort by", selection: $viewModel.sortOption) {
                    ForEach(DeviceSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(.purple)

                Spacer()

                Toggle(isOn: $viewModel.showHidden) {
                    Label("Hidden", systemImage: "eye.slash")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(viewModel.showHidden ? .purple : .gray)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Devices Found")
                .font(.headline)
            Text(viewModel.isTracking
                 ? "Scanning for BLE devices..."
                 : "Tap the play button to start scanning")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Device List

    private var deviceListView: some View {
        List {
            ForEach(viewModel.filteredDevices) { device in
                DeviceTrackerRow(device: device)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectDevice(device)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.toggleFavorite(device: device)
                        } label: {
                            Label(
                                device.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: device.isFavorite ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(.yellow)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            viewModel.toggleHidden(device: device)
                        } label: {
                            Label(
                                device.isHidden ? "Show" : "Hide",
                                systemImage: device.isHidden ? "eye" : "eye.slash"
                            )
                        }
                        .tint(.gray)
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Device Row

private struct DeviceTrackerRow: View {
    let device: TrackedDevice

    var body: some View {
        HStack(spacing: 12) {
            // Signal strength indicator
            signalIndicator

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if device.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    if device.isHidden {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(device.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(device.sightingCount)", systemImage: "eye")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Last: \(device.lastSeen, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // RSSI value
            VStack(alignment: .trailing) {
                Text("\(device.rssi) dBm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(rssiColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var signalIndicator: some View {
        ZStack {
            Circle()
                .fill(rssiColor.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: signalIconName)
                .font(.system(size: 16))
                .foregroundStyle(rssiColor)
        }
    }

    private var signalIconName: String {
        switch device.rssi {
        case -50...0: return "wifi"
        case -70 ..< -50: return "wifi"
        case -90 ..< -70: return "wifi.exclamationmark"
        default: return "wifi.slash"
        }
    }

    private var rssiColor: Color {
        switch device.rssi {
        case -50...0: return .green
        case -70 ..< -50: return .yellow
        case -90 ..< -70: return .orange
        default: return .red
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Device Detail Sheet

private struct DeviceDetailSheet: View {
    let device: TrackedDevice
    @Bindable var viewModel: DeviceTrackerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Identity") {
                    LabeledContent("Name", value: device.name)
                    LabeledContent("Address", value: device.address)
                }

                Section("Signal") {
                    LabeledContent("RSSI", value: "\(device.rssi) dBm")
                    LabeledContent("Sightings", value: "\(device.sightingCount)")
                }

                Section("Timestamps") {
                    LabeledContent("First Seen") {
                        Text(device.firstSeen, style: .date)
                        Text(device.firstSeen, style: .time)
                    }
                    LabeledContent("Last Seen") {
                        Text(device.lastSeen, style: .date)
                        Text(device.lastSeen, style: .time)
                    }
                }

                Section("Actions") {
                    Button {
                        viewModel.toggleFavorite(device: device)
                        dismiss()
                    } label: {
                        Label(
                            device.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: device.isFavorite ? "star.slash" : "star.fill"
                        )
                    }

                    Button {
                        viewModel.toggleHidden(device: device)
                        dismiss()
                    } label: {
                        Label(
                            device.isHidden ? "Unhide Device" : "Hide Device",
                            systemImage: device.isHidden ? "eye" : "eye.slash"
                        )
                    }
                }
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// DeviceTrackerViewModel.swift
// Vesper - AI-powered Flipper Zero controller
// BLE device tracking and monitoring

import Foundation
import Observation

// MARK: - Sort Option

enum DeviceSortOption: String, CaseIterable, Identifiable {
    case lastSeen = "Last Seen"
    case firstSeen = "First Seen"
    case name = "Name"
    case sightingCount = "Most Seen"
    case signalStrength = "Signal Strength"

    var id: String { rawValue }
}

// MARK: - Tracked Device

struct TrackedDevice: Identifiable, Equatable {
    let id: String
    var name: String
    var address: String
    var rssi: Int
    var firstSeen: Date
    var lastSeen: Date
    var sightingCount: Int
    var isFavorite: Bool
    var isHidden: Bool

    init(
        id: String,
        name: String,
        address: String,
        rssi: Int = 0,
        firstSeen: Date = Date(),
        lastSeen: Date = Date(),
        sightingCount: Int = 1,
        isFavorite: Bool = false,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.rssi = rssi
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.sightingCount = sightingCount
        self.isFavorite = isFavorite
        self.isHidden = isHidden
    }
}

// MARK: - ViewModel

@Observable
class DeviceTrackerViewModel {
    private let bleManager: FlipperBLEManager

    // MARK: - State

    var trackedDevices: [TrackedDevice] = []
    var searchQuery: String = ""
    var sortOption: DeviceSortOption = .lastSeen
    var showHidden: Bool = false
    var isTracking: Bool = false
    var selectedDevice: TrackedDevice?

    // Track favorites/hidden by device ID (in-memory; does not persist across launches)
    private var favoriteIds: Set<String> = []
    private var hiddenIds: Set<String> = []

    // MARK: - Computed

    var filteredDevices: [TrackedDevice] {
        var devices = trackedDevices

        // Filter hidden
        if !showHidden {
            devices = devices.filter { !$0.isHidden }
        }

        // Search filter
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            devices = devices.filter {
                $0.name.lowercased().contains(query) ||
                $0.address.lowercased().contains(query)
            }
        }

        // Sort
        switch sortOption {
        case .lastSeen:
            devices.sort { $0.lastSeen > $1.lastSeen }
        case .firstSeen:
            devices.sort { $0.firstSeen > $1.firstSeen }
        case .name:
            devices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .sightingCount:
            devices.sort { $0.sightingCount > $1.sightingCount }
        case .signalStrength:
            devices.sort { $0.rssi > $1.rssi }
        }

        // Favorites pinned to top
        let favorites = devices.filter { $0.isFavorite }
        let others = devices.filter { !$0.isFavorite }
        return favorites + others
    }

    var deviceCount: Int { filteredDevices.count }
    var totalDeviceCount: Int { trackedDevices.count }

    // MARK: - Init

    init(bleManager: FlipperBLEManager) {
        self.bleManager = bleManager
    }

    // MARK: - Tracking

    func startTracking() {
        isTracking = true
        bleManager.startScanning()
        // Start a polling task to sync discovered devices
        Task { @MainActor in
            while isTracking {
                updateTrackedDevices()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second refresh
            }
        }
    }

    func stopTracking() {
        isTracking = false
        bleManager.stopScanning()
    }

    // MARK: - Device Management

    func toggleFavorite(device: TrackedDevice) {
        if favoriteIds.contains(device.id) {
            favoriteIds.remove(device.id)
        } else {
            favoriteIds.insert(device.id)
        }
        refreshFlags()
    }

    func toggleHidden(device: TrackedDevice) {
        if hiddenIds.contains(device.id) {
            hiddenIds.remove(device.id)
        } else {
            hiddenIds.insert(device.id)
        }
        refreshFlags()
    }

    func selectDevice(_ device: TrackedDevice?) {
        selectedDevice = device
    }

    // MARK: - Internal

    private func updateTrackedDevices() {
        let now = Date()
        let discovered = bleManager.discoveredDevices

        for device in discovered {
            if let index = trackedDevices.firstIndex(where: { $0.id == device.id }) {
                // Update existing
                trackedDevices[index].rssi = device.rssi
                trackedDevices[index].lastSeen = now
                trackedDevices[index].sightingCount += 1
                trackedDevices[index].name = device.name
            } else {
                // New device
                let tracked = TrackedDevice(
                    id: device.id,
                    name: device.name,
                    address: device.id,
                    rssi: device.rssi,
                    firstSeen: now,
                    lastSeen: now,
                    sightingCount: 1,
                    isFavorite: favoriteIds.contains(device.id),
                    isHidden: hiddenIds.contains(device.id)
                )
                trackedDevices.append(tracked)
            }
        }

        refreshFlags()
    }

    private func refreshFlags() {
        for i in trackedDevices.indices {
            trackedDevices[i].isFavorite = favoriteIds.contains(trackedDevices[i].id)
            trackedDevices[i].isHidden = hiddenIds.contains(trackedDevices[i].id)
        }
    }
}

// FlipperBLEManager.swift
// Vesper - AI-powered Flipper Zero controller
// CoreBluetooth implementation for Flipper Zero BLE communication

import CoreBluetooth
import Combine
import os.log

private let logger = Logger(subsystem: "com.vesper.flipper", category: "BLE")

@Observable
class FlipperBLEManager: NSObject {

    // MARK: - Public State

    var connectionState: ConnectionState = .disconnected
    var discoveredDevices: [FlipperDevice] = []
    var connectedDevice: FlipperDevice? = nil

    // MARK: - Private State

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var serialTxCharacteristic: CBCharacteristic?
    private var serialRxCharacteristic: CBCharacteristic?
    private var negotiatedMTU: Int = 23

    private var pendingOperations: [String: CheckedContinuation<Data, Error>] = [:]
    private var pendingWriteAcks: [String: CheckedContinuation<Void, Error>] = [:]
    private var dataBuffer = Data()

    private var reconnectTask: Task<Void, Never>?
    private var keepaliveTask: Task<Void, Never>?
    private var scanTimeoutTask: Task<Void, Never>?
    private var lastConnectedDeviceId: String?
    private var reconnectAttemptCount: Int = 0
    private var isReconnecting: Bool = false
    private var notificationsReady: Bool = false
    private var waitingForNotifications: Bool = false
    private var intentionalDisconnect: Bool = false
    private var lastBleActivityTime: Date = Date()

    /// Dedicated BLE queue — keeps CBCentralManager callbacks off the main thread.
    private let bleQueue = DispatchQueue(label: "com.vesper.flipper.ble", qos: .userInitiated)

    /// Serial write queue — ensures only one write operation at a time.
    private let writeQueue = DispatchQueue(label: "com.vesper.flipper.write", qos: .userInitiated)
    private var isWriting = false

    /// Callback invoked when raw data arrives from the Flipper's serial RX characteristic.
    var onDataReceived: ((Data) -> Void)?

    /// Settings store for device persistence and auto-connect.
    var settingsStore: SettingsStore?

    // MARK: - GATT UUIDs

    // Advertisement service UUIDs (match official Flipper iOS app)
    static let flipperServiceF6UUID = CBUUID(string: "3080")
    static let flipperServiceBlackUUID = CBUUID(string: "3081")
    static let flipperServiceWhiteUUID = CBUUID(string: "3082")
    static let flipperServiceClearUUID = CBUUID(string: "3083")

    // Serial service & characteristics
    static let serialServiceUUID = CBUUID(string: "8fe5b3d5-2e7f-4a98-2a48-7acc60fe0000")
    static let serialTxUUID = CBUUID(string: "19ed82ae-ed21-4c9d-4145-228e62fe0000")
    static let serialRxUUID = CBUUID(string: "19ed82ae-ed21-4c9d-4145-228e61fe0000")

    static let scanServiceUUIDs: [CBUUID] = [
        flipperServiceF6UUID,
        flipperServiceBlackUUID,
        flipperServiceWhiteUUID,
        flipperServiceClearUUID,
    ]

    // MARK: - Constants (matched to Android FlipperBleService.kt)

    private static let defaultATTMTU: Int = 23               // Android DEFAULT_ATT_MTU
    private static let requestedATTMTU: Int = 517             // Android REQUESTED_ATT_MTU
    private static let attWriteOverhead: Int = 3              // Android ATT_WRITE_OVERHEAD_BYTES
    private static let minBLEChunkBytes: Int = 20             // Android MIN_BLE_CHUNK_BYTES
    private static let maxReconnectAttempts: Int = 3          // Android MAX_TIMEOUT_RECONNECT_ATTEMPTS
    private static let reconnectBaseDelayMs: Double = 1000    // Android TIMEOUT_RECONNECT_DELAY_MS
    private static let reconnectBackoffStepMs: Double = 500   // Android TIMEOUT_RECONNECT_BACKOFF_STEP_MS
    private static let scanTimeoutSeconds: TimeInterval = 30.0
    private static let keepaliveIntervalSeconds: TimeInterval = 3.0  // Android BLE_KEEPALIVE_INTERVAL_MS
    private static let keepaliveIdleThresholdSeconds: TimeInterval = 3.5  // Android BLE_KEEPALIVE_IDLE_THRESHOLD_MS
    private static let writeInterChunkDelay: UInt64 = 8_000_000      // 8ms (Android WRITE_NO_RESPONSE_CHUNK_DELAY_MS)
    private static let commandTimeoutSeconds: TimeInterval = 5.0
    private static let writeAckTimeoutSeconds: TimeInterval = 3.0    // Android WRITE_ACK_TIMEOUT_MS
    private static let maxWriteStartAttempts: Int = 5                 // Android MAX_WRITE_START_ATTEMPTS
    private static let writeStartRetryDelayMs: UInt64 = 80_000_000   // 80ms

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
    }

    // MARK: - Public API

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot scan: Bluetooth not powered on (state: \(self.centralManager.state.rawValue))")
            if centralManager.state == .unauthorized {
                DispatchQueue.main.async { self.connectionState = .error("Bluetooth permission denied") }
            } else if centralManager.state == .poweredOff {
                DispatchQueue.main.async { self.connectionState = .error("Bluetooth is turned off") }
            }
            return
        }

        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
            self.connectionState = .scanning
        }

        // Check for Flippers already connected by another app (e.g. official Flipper app)
        let alreadyConnected = centralManager.retrieveConnectedPeripherals(withServices: [Self.serialServiceUUID] + Self.scanServiceUUIDs)
        for peripheral in alreadyConnected {
            let deviceId = peripheral.identifier.uuidString
            let deviceName = peripheral.name ?? "Flipper (\(deviceId.prefix(8)))"
            let device = FlipperDevice(id: deviceId, name: deviceName, rssi: 0, isConnected: false)
            DispatchQueue.main.async { self.discoveredDevices.append(device) }
            logger.info("Found already-connected Flipper: \(deviceName) [\(deviceId)]")
        }

        // Scan for advertising Flippers (matching official Flipper iOS app)
        centralManager.scanForPeripherals(withServices: Self.scanServiceUUIDs)

        logger.info("Started BLE scan for Flipper devices")

        scanTimeoutTask?.cancel()
        scanTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.scanTimeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.connectionState == .scanning else { return }
                self.stopScanning()
                if self.discoveredDevices.isEmpty {
                    self.connectionState = .error("No Flipper devices found")
                }
            }
        }
    }

    func stopScanning() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil

        guard centralManager.isScanning else { return }
        centralManager.stopScan()

        DispatchQueue.main.async {
            if self.connectionState == .scanning {
                self.connectionState = .disconnected
            }
        }
        logger.info("Stopped BLE scan")
    }

    func connect(device: FlipperDevice) {
        // Guard duplicate connects
        guard connectionState != .connecting, connectionState != .connected else {
            logger.info("Already connecting/connected, ignoring duplicate connect")
            return
        }

        stopScanning()
        reconnectAttemptCount = 0
        isReconnecting = false
        intentionalDisconnect = false
        lastConnectedDeviceId = device.id

        guard let peripheral = findPeripheral(for: device) else {
            DispatchQueue.main.async { self.connectionState = .error("Device not found: \(device.name)") }
            return
        }

        DispatchQueue.main.async { self.connectionState = .connecting }
        connectedPeripheral = peripheral
        peripheral.delegate = self

        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])

        logger.info("Connecting to \(device.name) [\(device.id)]")
    }

    func disconnect() {
        intentionalDisconnect = true
        reconnectTask?.cancel()
        reconnectTask = nil
        keepaliveTask?.cancel()
        keepaliveTask = nil
        isReconnecting = false
        reconnectAttemptCount = 0
        lastConnectedDeviceId = nil

        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        cleanupConnection()
        DispatchQueue.main.async { self.connectionState = .disconnected }
        logger.info("Disconnected from Flipper")
    }

    /// Attempts to reconnect to the last known device if auto-connect is enabled.
    func autoReconnect() {
        guard let settings = settingsStore,
              settings.autoConnect,
              let address = settings.lastDeviceAddress else {
            return
        }

        let name = settings.lastDeviceName ?? "Flipper"
        let device = FlipperDevice(id: address, name: name)
        connect(device: device)
    }

    func sendData(_ data: Data) async throws {
        guard let peripheral = connectedPeripheral,
              let txCharacteristic = serialTxCharacteristic else {
            throw FlipperBLEError.notConnected
        }

        guard peripheral.state == .connected else {
            throw FlipperBLEError.notConnected
        }

        lastBleActivityTime = Date()

        // Split data into MTU-sized chunks
        let chunkSize = max(negotiatedMTU - Self.attWriteOverhead, Self.minBLEChunkBytes)
        var offset = 0

        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data[offset..<end]

            try await writeChunkWithRetry(Data(chunk), to: peripheral, characteristic: txCharacteristic)

            offset = end

            // Small delay between chunks to avoid overwhelming the BLE link
            if offset < data.count {
                try await Task.sleep(nanoseconds: Self.writeInterChunkDelay)
            }
        }
    }

    /// Send a framed command and wait for a complete response frame.
    func sendFramedData(_ data: Data) async throws -> Data {
        let operationId = UUID().uuidString

        return try await withCheckedThrowingContinuation { continuation in
            pendingOperations[operationId] = continuation

            Task {
                do {
                    try await sendData(data)
                } catch {
                    if let cont = pendingOperations.removeValue(forKey: operationId) {
                        cont.resume(throwing: error)
                    }
                }

                // Set a timeout for the response
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(Self.commandTimeoutSeconds * 1_000_000_000))
                    if let cont = self.pendingOperations.removeValue(forKey: operationId) {
                        cont.resume(throwing: FlipperBLEError.timeout)
                    }
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func findPeripheral(for device: FlipperDevice) -> CBPeripheral? {
        let connected = centralManager.retrieveConnectedPeripherals(withServices: [Self.serialServiceUUID] + Self.scanServiceUUIDs)
        if let match = connected.first(where: { $0.identifier.uuidString == device.id }) {
            return match
        }
        if let uuid = UUID(uuidString: device.id) {
            return centralManager.retrievePeripherals(withIdentifiers: [uuid]).first
        }
        return nil
    }

    /// Write a single chunk with retry logic matching Android (MAX_WRITE_START_ATTEMPTS attempts, 80ms between retries).
    private func writeChunkWithRetry(_ chunk: Data, to peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
        let writeType: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse

        for attempt in 1...Self.maxWriteStartAttempts {
            do {
                if writeType == .withResponse {
                    let writeId = "write_\(UUID().uuidString)"
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        pendingWriteAcks[writeId] = continuation
                        peripheral.writeValue(chunk, for: characteristic, type: writeType)

                        // Timeout for the write acknowledgment
                        Task { [weak self] in
                            try? await Task.sleep(nanoseconds: UInt64(Self.writeAckTimeoutSeconds * 1_000_000_000))
                            if let cont = self?.pendingWriteAcks.removeValue(forKey: writeId) {
                                cont.resume(throwing: FlipperBLEError.writeTimeout)
                            }
                        }
                    }
                } else {
                    peripheral.writeValue(chunk, for: characteristic, type: writeType)
                }
                return // Success
            } catch {
                if attempt < Self.maxWriteStartAttempts {
                    logger.warning("Write attempt \(attempt)/\(Self.maxWriteStartAttempts) failed, retrying in 80ms")
                    try await Task.sleep(nanoseconds: Self.writeStartRetryDelayMs)
                } else {
                    throw error
                }
            }
        }
    }

    private func cleanupConnection() {
        serialTxCharacteristic = nil
        serialRxCharacteristic = nil
        connectedPeripheral = nil
        notificationsReady = false
        waitingForNotifications = false
        negotiatedMTU = Self.defaultATTMTU
        dataBuffer.removeAll()

        DispatchQueue.main.async { self.connectedDevice = nil }

        // Fail all pending operations
        let pending = pendingOperations
        pendingOperations.removeAll()
        for (_, continuation) in pending {
            continuation.resume(throwing: FlipperBLEError.disconnected)
        }

        let pendingWrites = pendingWriteAcks
        pendingWriteAcks.removeAll()
        for (_, continuation) in pendingWrites {
            continuation.resume(throwing: FlipperBLEError.disconnected)
        }
    }

    private func attemptReconnect() {
        guard !isReconnecting else { return }
        guard reconnectAttemptCount < Self.maxReconnectAttempts else {
            DispatchQueue.main.async {
                self.connectionState = .error("Reconnection failed after \(Self.maxReconnectAttempts) attempts")
            }
            lastConnectedDeviceId = nil
            return
        }
        guard let deviceId = lastConnectedDeviceId else { return }

        isReconnecting = true
        reconnectAttemptCount += 1
        let attempt = reconnectAttemptCount
        // Linear backoff: 1s, 1.5s, 2s (matching Android)
        let delayMs = Self.reconnectBaseDelayMs + Double(attempt - 1) * Self.reconnectBackoffStepMs
        let delaySeconds = delayMs / 1000.0

        logger.info("Scheduling reconnect attempt \(attempt)/\(Self.maxReconnectAttempts) in \(delaySeconds)s")
        DispatchQueue.main.async { self.connectionState = .connecting }

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delayMs * 1_000_000))
            guard !Task.isCancelled else { return }

            guard let self else { return }
            self.isReconnecting = false

            guard let uuid = UUID(uuidString: deviceId),
                  let peripheral = self.centralManager.retrievePeripherals(withIdentifiers: [uuid]).first else {
                logger.warning("Cannot find peripheral for reconnect: \(deviceId)")
                self.attemptReconnect()
                return
            }

            self.connectedPeripheral = peripheral
            peripheral.delegate = self
            self.centralManager.connect(peripheral, options: [
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
            ])
        }
    }

    private func startKeepalive() {
        keepaliveTask?.cancel()
        keepaliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.keepaliveIntervalSeconds * 1_000_000_000))
                guard !Task.isCancelled, let self else { break }
                guard let peripheral = self.connectedPeripheral,
                      peripheral.state == .connected else { continue }

                let idleTime = Date().timeIntervalSince(self.lastBleActivityTime)
                if idleTime >= Self.keepaliveIdleThresholdSeconds {
                    peripheral.readRSSI()
                    logger.debug("Keepalive ping sent (idle \(String(format: "%.1f", idleTime))s)")
                }
            }
        }
    }

    /// Process incoming data: buffer it and attempt frame reassembly.
    private func processIncomingData(_ data: Data) {
        lastBleActivityTime = Date()

        // Forward raw data to the protocol handler
        onDataReceived?(data)

        // Also attempt frame reassembly for pending framed operations
        dataBuffer.append(data)
        attemptFrameReassembly()
    }

    /// Frame reassembly using varint length prefix (matching Flipper RPC protobuf framing).
    private func attemptFrameReassembly() {
        while !dataBuffer.isEmpty {
            var offset = 0
            var length: UInt64 = 0
            var shift: UInt64 = 0
            var varintComplete = false

            while offset < dataBuffer.count {
                let byte = dataBuffer[offset]
                length |= UInt64(byte & 0x7F) << shift
                offset += 1
                if byte & 0x80 == 0 { varintComplete = true; break }
                shift += 7
                if shift > 35 { dataBuffer.removeAll(); return }
            }

            guard varintComplete else { return }

            let frameLen = Int(length)
            guard frameLen > 0, frameLen <= 256 * 1024 else { dataBuffer.removeAll(); return }
            guard dataBuffer.count >= offset + frameLen else { return }

            let frameData = dataBuffer[offset..<(offset + frameLen)]
            dataBuffer.removeSubrange(0..<(offset + frameLen))

            if let (id, continuation) = pendingOperations.first {
                pendingOperations.removeValue(forKey: id)
                continuation.resume(returning: Data(frameData))
            }
        }
    }

    // MARK: - Connection Finalization

    private func finalizeConnection(peripheral: CBPeripheral) {
        // Query MTU now that characteristics are discovered and notifications enabled
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        negotiatedMTU = max(mtu, Self.defaultATTMTU)
        logger.info("Negotiated MTU: \(self.negotiatedMTU)")

        let deviceName = peripheral.name ?? "Flipper Zero"
        let deviceId = peripheral.identifier.uuidString

        DispatchQueue.main.async {
            self.connectedDevice = FlipperDevice(
                id: deviceId,
                name: deviceName,
                rssi: 0,
                isConnected: true
            )
            self.connectionState = .connected
        }

        // Persist last connected device for auto-reconnect
        settingsStore?.lastDeviceAddress = deviceId
        settingsStore?.lastDeviceName = deviceName

        lastBleActivityTime = Date()
        startKeepalive()
        logger.info("Flipper connection fully established: \(deviceName)")
    }
}

// MARK: - CBCentralManagerDelegate

extension FlipperBLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("Bluetooth state changed: \(central.state.rawValue)")

        switch central.state {
        case .poweredOn:
            DispatchQueue.main.async {
                if self.connectionState == .error("Bluetooth is turned off") ||
                   self.connectionState == .error("Bluetooth permission denied") {
                    self.connectionState = .disconnected
                }
            }
        case .poweredOff:
            cleanupConnection()
            DispatchQueue.main.async { self.connectionState = .error("Bluetooth is turned off") }
        case .unauthorized:
            cleanupConnection()
            DispatchQueue.main.async { self.connectionState = .error("Bluetooth permission denied") }
        case .unsupported:
            DispatchQueue.main.async { self.connectionState = .error("Bluetooth LE not supported") }
        case .resetting:
            cleanupConnection()
            DispatchQueue.main.async { self.connectionState = .disconnected }
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let deviceId = peripheral.identifier.uuidString
        let deviceName = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Flipper (\(deviceId.prefix(8)))"

        let device = FlipperDevice(
            id: deviceId,
            name: deviceName,
            rssi: RSSI.intValue,
            isConnected: false
        )

        DispatchQueue.main.async {
            if let existingIndex = self.discoveredDevices.firstIndex(where: { $0.id == deviceId }) {
                self.discoveredDevices[existingIndex] = device
            } else {
                self.discoveredDevices.append(device)
                logger.info("Discovered Flipper: \(deviceName) [\(deviceId)] RSSI=\(RSSI.intValue)")
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to peripheral: \(peripheral.identifier.uuidString)")

        reconnectAttemptCount = 0
        isReconnecting = false
        intentionalDisconnect = false
        reconnectTask?.cancel()

        // Do NOT query MTU here — it returns 20 before service discovery.
        // MTU is queried later in finalizeConnection() after characteristics are ready.

        // Discover services
        peripheral.discoverServices([Self.serialServiceUUID] + Self.scanServiceUUIDs)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let msg = error?.localizedDescription ?? "Unknown error"
        logger.error("Failed to connect: \(msg)")

        if lastConnectedDeviceId != nil, !intentionalDisconnect {
            attemptReconnect()
        } else {
            DispatchQueue.main.async { self.connectionState = .error("Connection failed: \(msg)") }
            cleanupConnection()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from peripheral (error: \(error?.localizedDescription ?? "none"))")

        let wasConnected = connectedDevice != nil
        cleanupConnection()
        keepaliveTask?.cancel()

        // Don't auto-reconnect if user disconnected intentionally
        if wasConnected, lastConnectedDeviceId != nil, !intentionalDisconnect {
            attemptReconnect()
        } else {
            DispatchQueue.main.async { self.connectionState = .disconnected }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension FlipperBLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            logger.error("Service discovery failed: \(error.localizedDescription)")
            DispatchQueue.main.async { self.connectionState = .error("Service discovery failed") }
            return
        }

        guard let services = peripheral.services else {
            logger.warning("No services found on peripheral")
            DispatchQueue.main.async { self.connectionState = .error("No compatible services found") }
            return
        }

        logger.info("Discovered \(services.count) service(s)")

        for service in services {
            peripheral.discoverCharacteristics(
                [Self.serialTxUUID, Self.serialRxUUID],
                for: service
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            logger.error("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case Self.serialTxUUID:
                serialTxCharacteristic = characteristic
                logger.info("Found Serial TX characteristic")

            case Self.serialRxUUID:
                serialRxCharacteristic = characteristic
                logger.info("Found Serial RX characteristic")

                // Subscribe to notifications — wait for the callback before finalizing
                waitingForNotifications = true
                peripheral.setNotifyValue(true, for: characteristic)

                // Timeout in case didUpdateNotificationState never fires
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s timeout
                    guard let self, self.waitingForNotifications else { return }
                    self.waitingForNotifications = false
                    logger.warning("Notification readiness timeout — finalizing anyway")
                    if self.serialTxCharacteristic != nil && self.serialRxCharacteristic != nil {
                        self.finalizeConnection(peripheral: peripheral)
                    }
                }

            default:
                break
            }
        }

        // If TX is ready and we're NOT waiting for RX notifications, finalize now
        // (This handles the case where RX was discovered in a previous callback)
        if serialTxCharacteristic != nil && serialRxCharacteristic != nil && !waitingForNotifications {
            finalizeConnection(peripheral: peripheral)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            logger.error("Notification state update failed: \(error.localizedDescription)")
            // Still try to finalize if we were waiting
            if waitingForNotifications {
                waitingForNotifications = false
                if serialTxCharacteristic != nil && serialRxCharacteristic != nil {
                    finalizeConnection(peripheral: peripheral)
                }
            }
            return
        }

        if characteristic.uuid == Self.serialRxUUID && characteristic.isNotifying {
            notificationsReady = true
            logger.info("Serial RX notifications enabled")

            // Now finalize the connection — notifications are confirmed ready
            if waitingForNotifications {
                waitingForNotifications = false
                if serialTxCharacteristic != nil && serialRxCharacteristic != nil {
                    finalizeConnection(peripheral: peripheral)
                }
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            logger.error("Characteristic value update error: \(error.localizedDescription)")
            return
        }

        guard characteristic.uuid == Self.serialRxUUID,
              let data = characteristic.value,
              !data.isEmpty else {
            return
        }

        processIncomingData(data)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        // Find and complete the oldest pending write acknowledgment
        if let key = pendingWriteAcks.keys.sorted().first,
           let continuation = pendingWriteAcks.removeValue(forKey: key) {
            if let error {
                continuation.resume(throwing: FlipperBLEError.writeFailed(error.localizedDescription))
            } else {
                continuation.resume()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error {
            logger.debug("RSSI read error: \(error.localizedDescription)")
            return
        }

        // Update device RSSI on main thread
        DispatchQueue.main.async {
            if var device = self.connectedDevice {
                device.rssi = RSSI.intValue
                self.connectedDevice = device
            }
        }
    }
}

// MARK: - BLE Errors

enum FlipperBLEError: Error, LocalizedError {
    case notConnected
    case disconnected
    case timeout
    case writeTimeout
    case writeFailed(String)
    case bluetoothOff
    case bluetoothUnauthorized
    case serviceNotFound
    case characteristicNotFound

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Flipper device"
        case .disconnected:
            return "Disconnected from Flipper device"
        case .timeout:
            return "Command timed out"
        case .writeTimeout:
            return "Write acknowledgment timed out"
        case .writeFailed(let reason):
            return "Write failed: \(reason)"
        case .bluetoothOff:
            return "Bluetooth is turned off"
        case .bluetoothUnauthorized:
            return "Bluetooth permission denied"
        case .serviceNotFound:
            return "Flipper serial service not found"
        case .characteristicNotFound:
            return "Flipper serial characteristic not found"
        }
    }
}

import SwiftUI

@Observable
class OpsCenterViewModel {
    private let bleManager: FlipperBLEManager
    private let commandExecutor: CommandExecuting
    private let auditService: AuditService

    var isDeviceConnected: Bool {
        bleManager.connectionState == .connected
    }

    var deviceName: String {
        bleManager.connectedDevice?.name ?? "No Device"
    }

    var recentActions: [AuditEntry] {
        Array(auditService.recentEntries.prefix(10))
    }

    var pipelineHealth: PipelineHealth = .idle

    // Runbook definitions
    static let runbooks: [(id: String, name: String, description: String, icon: String)] = [
        ("health_check", "Health Check", "Device info, storage, battery status", "heart.text.square"),
        ("storage_audit", "Storage Audit", "List all directories, check free space", "externaldrive"),
        ("signal_inventory", "Signal Inventory", "Scan Sub-GHz, IR, NFC, RFID files", "antenna.radiowaves.left.and.right"),
        ("app_inventory", "App Inventory", "List installed .fap applications", "app.badge.checkmark"),
        ("security_scan", "Security Scan", "Check for sensitive files, validate paths", "lock.shield"),
    ]

    init(bleManager: FlipperBLEManager, commandExecutor: CommandExecuting, auditService: AuditService) {
        self.bleManager = bleManager
        self.commandExecutor = commandExecutor
        self.auditService = auditService
    }

    func runRunbook(_ runbookId: String) {
        pipelineHealth = .running(runbookId)
        Task {
            let command = ExecuteCommand(
                action: .runRunbook,
                args: CommandArgs(runbookId: runbookId),
                justification: "User-initiated runbook",
                expectedEffect: "Diagnostic information gathered"
            )
            let sessionId = UUID().uuidString
            let result = await commandExecutor.execute(command, sessionId: sessionId)
            if result.requiresConfirmation, let approvalId = result.pendingApprovalId {
                pipelineHealth = .awaitingApproval(approvalId: approvalId, runbookId: runbookId)
            } else if result.success {
                pipelineHealth = .completed(result.data?.message ?? "Runbook completed")
            } else {
                pipelineHealth = .error(result.error ?? "Runbook failed")
            }
        }
    }

    func approveRunbook(_ approvalId: String) {
        guard case .awaitingApproval(_, let runbookId) = pipelineHealth else { return }
        pipelineHealth = .running(runbookId)
        Task {
            let result = await commandExecutor.approve(approvalId, sessionId: UUID().uuidString)
            if result.success {
                pipelineHealth = .completed(result.data?.message ?? "Runbook completed")
            } else {
                pipelineHealth = .error(result.error ?? "Runbook failed")
            }
        }
    }

    func denyRunbook(_ approvalId: String) {
        Task {
            _ = await commandExecutor.reject(approvalId, sessionId: UUID().uuidString)
            pipelineHealth = .idle
        }
    }
}

enum PipelineHealth: Equatable {
    case idle
    case running(String)
    case awaitingApproval(approvalId: String, runbookId: String)
    case completed(String)
    case error(String)
}

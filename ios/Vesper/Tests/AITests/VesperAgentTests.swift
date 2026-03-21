// VesperAgentTests.swift
// Vesper - Unit tests for VesperAgent models and serialization

import XCTest
@testable import Vesper

final class VesperAgentTests: XCTestCase {

    // MARK: - ExecuteCommand Serialization

    func testExecuteCommandEncodesWithSnakeCaseKeys() throws {
        let command = ExecuteCommand(
            action: .listDirectory,
            args: CommandArgs(path: "/ext/subghz"),
            justification: "List files",
            expectedEffect: "Show directory listing"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(command)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"expected_effect\""), "Should use snake_case for expectedEffect")
        XCTAssertTrue(json.contains("\"list_directory\""), "Should encode action as snake_case raw value")
        XCTAssertFalse(json.contains("\"expectedEffect\""), "Should not use camelCase")
    }

    func testExecuteCommandRoundTrip() throws {
        let command = ExecuteCommand(
            action: .writeFile,
            args: CommandArgs(
                path: "/ext/test.txt",
                content: "Hello, Flipper!"
            ),
            justification: "Create test file",
            expectedEffect: "File created on SD card"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(command)
        let decoded = try decoder.decode(ExecuteCommand.self, from: data)

        XCTAssertEqual(decoded.action, .writeFile)
        XCTAssertEqual(decoded.args.path, "/ext/test.txt")
        XCTAssertEqual(decoded.args.content, "Hello, Flipper!")
        XCTAssertEqual(decoded.justification, "Create test file")
        XCTAssertEqual(decoded.expectedEffect, "File created on SD card")
    }

    func testExecuteCommandWithAllArgs() throws {
        let command = ExecuteCommand(
            action: .copy,
            args: CommandArgs(
                path: "/ext/source.txt",
                destinationPath: "/ext/dest.txt",
                recursive: true
            ),
            justification: "Copy file",
            expectedEffect: "File copied"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(command)
        let json = String(data: data, encoding: .utf8)!

        // Verify snake_case keys
        XCTAssertTrue(json.contains("\"destination_path\""))
        XCTAssertFalse(json.contains("\"destinationPath\""))

        let decoded = try decoder.decode(ExecuteCommand.self, from: data)
        XCTAssertEqual(decoded.args.destinationPath, "/ext/dest.txt")
        XCTAssertEqual(decoded.args.recursive, true)
    }

    func testExecuteCommandDefaultRecursiveFalse() throws {
        let command = ExecuteCommand(
            action: .delete,
            args: CommandArgs(path: "/ext/test.txt"),
            justification: "Delete file",
            expectedEffect: "File deleted"
        )

        XCTAssertFalse(command.args.recursive)
    }

    func testExecuteCommandEquatable() {
        let cmd1 = ExecuteCommand(
            action: .readFile,
            args: CommandArgs(path: "/ext/test.txt"),
            justification: "test",
            expectedEffect: "test"
        )
        let cmd2 = ExecuteCommand(
            action: .readFile,
            args: CommandArgs(path: "/ext/test.txt"),
            justification: "test",
            expectedEffect: "test"
        )
        XCTAssertEqual(cmd1, cmd2)
    }

    // MARK: - CommandResult Serialization

    func testCommandResultEncodesWithSnakeCaseKeys() throws {
        let result = CommandResult(
            success: true,
            action: .listDirectory,
            data: CommandResultData(
                entries: [
                    FileEntry(name: "test.sub", path: "/ext/subghz/test.sub", isDirectory: false, size: 1024)
                ]
            ),
            executionTimeMs: 150
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"execution_time_ms\""))
        XCTAssertTrue(json.contains("\"is_directory\""))
        XCTAssertFalse(json.contains("\"executionTimeMs\""))
    }

    func testCommandResultRoundTrip() throws {
        let result = CommandResult(
            success: false,
            action: .readFile,
            error: "File not found",
            executionTimeMs: 42
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(result)
        let decoded = try decoder.decode(CommandResult.self, from: data)

        XCTAssertFalse(decoded.success)
        XCTAssertEqual(decoded.action, .readFile)
        XCTAssertEqual(decoded.error, "File not found")
        XCTAssertEqual(decoded.executionTimeMs, 42)
    }

    func testCommandResultWithConfirmation() throws {
        let result = CommandResult(
            success: false,
            action: .delete,
            requiresConfirmation: true,
            pendingApprovalId: "approval-123"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(result)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"requires_confirmation\""))
        XCTAssertTrue(json.contains("\"pending_approval_id\""))

        let decoded = try decoder.decode(CommandResult.self, from: data)
        XCTAssertTrue(decoded.requiresConfirmation)
        XCTAssertEqual(decoded.pendingApprovalId, "approval-123")
    }

    // MARK: - ToolCall Tests

    func testToolCallCreation() {
        let toolCall = ToolCall(
            id: "call-001",
            name: "execute_command",
            arguments: "{\"action\":\"list_directory\",\"args\":{\"path\":\"/ext\"}}"
        )

        XCTAssertEqual(toolCall.id, "call-001")
        XCTAssertEqual(toolCall.name, "execute_command")
        XCTAssertTrue(toolCall.arguments.contains("list_directory"))
    }

    func testToolCallRoundTrip() throws {
        let toolCall = ToolCall(
            id: "call-002",
            name: "execute_command",
            arguments: "{\"action\":\"read_file\"}"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(toolCall)
        let decoded = try decoder.decode(ToolCall.self, from: data)

        XCTAssertEqual(decoded.id, "call-002")
        XCTAssertEqual(decoded.name, "execute_command")
        XCTAssertEqual(decoded.arguments, "{\"action\":\"read_file\"}")
    }

    func testToolCallEquatable() {
        let tc1 = ToolCall(id: "same-id", name: "execute_command", arguments: "{}")
        let tc2 = ToolCall(id: "same-id", name: "execute_command", arguments: "{}")
        XCTAssertEqual(tc1, tc2)
    }

    func testToolCallAutoId() {
        let tc1 = ToolCall(name: "execute_command", arguments: "{}")
        let tc2 = ToolCall(name: "execute_command", arguments: "{}")
        // Auto-generated UUIDs should differ
        XCTAssertNotEqual(tc1.id, tc2.id)
    }

    // MARK: - ToolResult Tests

    func testToolResultRoundTrip() throws {
        let result = ToolResult(
            toolCallId: "call-001",
            content: "{\"success\": true}"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(result)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"tool_call_id\""))

        let decoded = try decoder.decode(ToolResult.self, from: data)
        XCTAssertEqual(decoded.toolCallId, "call-001")
        XCTAssertEqual(decoded.content, "{\"success\": true}")
    }

    // MARK: - ChatMessage Tests

    func testChatMessageUserCreation() {
        let message = ChatMessage(role: .user, content: "List files on the Flipper")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "List files on the Flipper")
        XCTAssertNil(message.toolCalls)
        XCTAssertNil(message.toolResults)
        XCTAssertFalse(message.isError)
    }

    func testChatMessageAssistantWithToolCalls() {
        let toolCall = ToolCall(
            id: "tc-1",
            name: "execute_command",
            arguments: "{}"
        )
        let message = ChatMessage(
            role: .assistant,
            content: "I'll list the files for you.",
            toolCalls: [toolCall]
        )

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.toolCalls?.count, 1)
        XCTAssertEqual(message.toolCalls?.first?.name, "execute_command")
    }

    func testChatMessageToolResult() {
        let result = ToolResult(toolCallId: "tc-1", content: "{\"entries\":[]}")
        let message = ChatMessage(
            role: .tool,
            content: "",
            toolResults: [result]
        )

        XCTAssertEqual(message.role, .tool)
        XCTAssertEqual(message.toolResults?.count, 1)
    }

    func testChatMessageRoundTrip() throws {
        let original = ChatMessage(
            id: "msg-001",
            role: .user,
            content: "Hello, Flipper!",
            timestamp: Date(timeIntervalSince1970: 1700000000),
            isError: false
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.id, "msg-001")
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content, "Hello, Flipper!")
        XCTAssertFalse(decoded.isError)
    }

    func testChatMessageEquality() {
        let msg1 = ChatMessage(id: "same-id", role: .user, content: "hello")
        let msg2 = ChatMessage(id: "same-id", role: .assistant, content: "different content")
        // Equality is based on id only
        XCTAssertEqual(msg1, msg2)
    }

    func testChatMessageInequalityDifferentIds() {
        let msg1 = ChatMessage(id: "id-1", role: .user, content: "hello")
        let msg2 = ChatMessage(id: "id-2", role: .user, content: "hello")
        XCTAssertNotEqual(msg1, msg2)
    }

    func testChatMessageAutoId() {
        let msg1 = ChatMessage(role: .user, content: "a")
        let msg2 = ChatMessage(role: .user, content: "b")
        XCTAssertNotEqual(msg1.id, msg2.id)
    }

    func testChatMessageWithImageAttachment() throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
        let attachment = ImageAttachment(data: imageData, mimeType: "image/png")
        let message = ChatMessage(
            role: .user,
            content: "What is this?",
            imageAttachments: [attachment]
        )

        XCTAssertEqual(message.imageAttachments?.count, 1)
        XCTAssertEqual(message.imageAttachments?.first?.mimeType, "image/png")
        XCTAssertEqual(message.imageAttachments?.first?.data, imageData)

        // Round-trip
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.imageAttachments?.count, 1)
        XCTAssertEqual(decoded.imageAttachments?.first?.mimeType, "image/png")
    }

    func testChatMessageSerializationWithSnakeCaseKeys() throws {
        let toolCall = ToolCall(id: "tc-1", name: "execute_command", arguments: "{}")
        let message = ChatMessage(
            role: .assistant,
            content: "test",
            toolCalls: [toolCall],
            isError: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"tool_calls\""))
        XCTAssertTrue(json.contains("\"is_error\""))
        XCTAssertFalse(json.contains("\"toolCalls\""))
        XCTAssertFalse(json.contains("\"isError\""))
    }

    func testChatMessageMetadataRoundTrip() throws {
        let message = ChatMessage(
            role: .assistant,
            content: "Pending approval",
            metadata: MessageMetadata(pendingApprovalId: "approval-123")
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.metadata?.pendingApprovalId, "approval-123")
    }

    // MARK: - ConversationState Tests

    func testConversationStateStartsEmpty() {
        let state = ConversationState()
        XCTAssertTrue(state.messages.isEmpty)
        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.error)
        XCTAssertNil(state.progress)
    }

    func testConversationStateSessionId() {
        let state1 = ConversationState()
        let state2 = ConversationState()
        // Each state should have a unique session ID
        XCTAssertNotEqual(state1.sessionId, state2.sessionId)
    }

    func testConversationStateWithMessages() {
        var state = ConversationState()
        state.messages.append(ChatMessage(role: .user, content: "Hello"))
        state.messages.append(ChatMessage(role: .assistant, content: "Hi there!"))

        XCTAssertEqual(state.messages.count, 2)
        XCTAssertEqual(state.messages[0].role, .user)
        XCTAssertEqual(state.messages[1].role, .assistant)
    }

    func testConversationStateDefaultsWithoutPendingApproval() {
        let state = ConversationState()
        XCTAssertNil(state.pendingApproval)
    }

    // MARK: - CommandAction Tests

    func testAllCommandActionsHaveRawValues() {
        // Ensure all actions serialize to snake_case
        for action in CommandAction.allCases {
            XCTAssertTrue(action.rawValue.contains("_") || action.rawValue.allSatisfy { $0.isLowercase },
                          "\(action) should have snake_case rawValue, got: \(action.rawValue)")
        }
    }

    func testCommandActionRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for action in CommandAction.allCases {
            let data = try encoder.encode(action)
            let decoded = try decoder.decode(CommandAction.self, from: data)
            XCTAssertEqual(decoded, action, "Round-trip failed for action: \(action)")
        }
    }

    // MARK: - CommandArgs Snake Case Keys

    func testCommandArgsSnakeCaseKeys() throws {
        let args = CommandArgs(
            appName: "nfc_app",
            appArgs: "--debug",
            signalName: "garage_door",
            downloadUrl: "https://example.com/file.sub",
            searchScope: "faphub",
            photoPrompt: "Describe what you see"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(args)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"app_name\""))
        XCTAssertTrue(json.contains("\"app_args\""))
        XCTAssertTrue(json.contains("\"signal_name\""))
        XCTAssertTrue(json.contains("\"download_url\""))
        XCTAssertTrue(json.contains("\"search_scope\""))
        XCTAssertTrue(json.contains("\"photo_prompt\""))
        XCTAssertFalse(json.contains("\"appName\""))
        XCTAssertFalse(json.contains("\"appArgs\""))
    }

    // MARK: - RiskLevel Serialization

    func testRiskLevelRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for level in RiskLevel.allCases {
            let data = try encoder.encode(level)
            let decoded = try decoder.decode(RiskLevel.self, from: data)
            XCTAssertEqual(decoded, level)
        }
    }

    // MARK: - FileEntry Tests

    func testFileEntryRoundTrip() throws {
        let entry = FileEntry(
            name: "test.sub",
            path: "/ext/subghz/test.sub",
            isDirectory: false,
            size: 2048,
            modifiedTimestamp: 1700000000
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(entry)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"is_directory\""))
        XCTAssertTrue(json.contains("\"modified_timestamp\""))

        let decoded = try decoder.decode(FileEntry.self, from: data)
        XCTAssertEqual(decoded.name, "test.sub")
        XCTAssertEqual(decoded.path, "/ext/subghz/test.sub")
        XCTAssertFalse(decoded.isDirectory)
        XCTAssertEqual(decoded.size, 2048)
        XCTAssertEqual(decoded.modifiedTimestamp, 1700000000)
    }

    func testFileEntryIdentifiable() {
        let entry = FileEntry(name: "test.sub", path: "/ext/subghz/test.sub", isDirectory: false)
        XCTAssertEqual(entry.id, "/ext/subghz/test.sub")
    }
}

// MARK: - Approval Flow Tests

private final class MockOpenRouterClient: OpenRouterClientProtocol, @unchecked Sendable {
    var chatResponses: [ChatCompletionResult]
    var recordedMessages: [[ChatMessage]] = []

    init(chatResponses: [ChatCompletionResult]) {
        self.chatResponses = chatResponses
    }

    func chat(messages: [ChatMessage], sessionId: String) async -> ChatCompletionResult {
        recordedMessages.append(messages)
        guard !chatResponses.isEmpty else {
            return .error("No mock response configured")
        }
        return chatResponses.removeFirst()
    }

    func formatResult(_ result: CommandResult) -> String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(result),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{\"success\":false,\"error\":\"formatting failed\"}"
    }

    func parseCommand(from arguments: String) -> (command: ExecuteCommand?, error: String?) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let data = arguments.data(using: .utf8) else {
            return (nil, "Invalid UTF-8")
        }
        do {
            return (try decoder.decode(ExecuteCommand.self, from: data), nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }
}

private final class MockCommandExecutor: CommandExecuting, @unchecked Sendable {
    var executeResult: CommandResult
    var approveResult: CommandResult
    var rejectResult: CommandResult
    var pendingApprovals: [String: PendingApproval] = [:]
    var executedCommands: [ExecuteCommand] = []
    var approvedApprovalIds: [String] = []
    var rejectedApprovalIds: [String] = []

    init(executeResult: CommandResult, approveResult: CommandResult, rejectResult: CommandResult) {
        self.executeResult = executeResult
        self.approveResult = approveResult
        self.rejectResult = rejectResult
    }

    func execute(_ command: ExecuteCommand, sessionId: String) async -> CommandResult {
        executedCommands.append(command)
        return executeResult
    }

    func approve(_ approvalId: String, sessionId: String) async -> CommandResult {
        approvedApprovalIds.append(approvalId)
        return approveResult
    }

    func reject(_ approvalId: String, sessionId: String) async -> CommandResult {
        rejectedApprovalIds.append(approvalId)
        return rejectResult
    }

    func getPendingApproval(_ approvalId: String) -> PendingApproval? {
        pendingApprovals[approvalId]
    }
}

private final class MockAuditService: AuditServiceProtocol, @unchecked Sendable {
    var currentSessionId: String?
    var entries: [AuditEntry] = []

    func startSession(deviceName: String?) {
        currentSessionId = UUID().uuidString
    }

    func endSession() {
        currentSessionId = nil
    }

    func log(_ entry: AuditEntry) {
        entries.append(entry)
    }
}

private final class MockChatStore: ChatStoreProtocol {
    var savedSessions: [String: [ChatMessage]] = [:]
    var savedDeviceNames: [String: String?] = [:]

    func save(sessionId: String, messages: [ChatMessage], deviceName: String?) throws {
        savedSessions[sessionId] = messages
        savedDeviceNames[sessionId] = deviceName
    }

    func loadMessages(sessionId: String) throws -> [ChatMessage] {
        savedSessions[sessionId] ?? []
    }

    func deleteSession(sessionId: String) throws {
        savedSessions.removeValue(forKey: sessionId)
        savedDeviceNames.removeValue(forKey: sessionId)
    }

    func listSessions() throws -> [ChatSessionSummary] {
        []
    }
}

final class VesperAgentApprovalFlowTests: XCTestCase {
    private func makeAgent(
        approvalId: String = "approval-123",
        approvedCommandResult: CommandResult = CommandResult(
            success: true,
            action: .delete,
            data: CommandResultData(message: "approved"),
            executionTimeMs: 10
        ),
        rejectedCommandResult: CommandResult = CommandResult(
            success: false,
            action: .delete,
            error: "rejected",
            executionTimeMs: 5
        )
    ) -> (VesperAgent, MockOpenRouterClient, MockCommandExecutor, MockChatStore) {
        let command = ExecuteCommand(
            action: .delete,
            args: CommandArgs(path: "/ext/test.txt"),
            justification: "Remove file",
            expectedEffect: "Delete file"
        )
        let commandData = try! JSONEncoder().encode(command)
        let toolCall = ToolCall(
            id: "tool-1",
            name: "execute_command",
            arguments: String(data: commandData, encoding: .utf8)!
        )
        let approvalResult = CommandResult(
            success: false,
            action: .delete,
            error: "Approval required",
            executionTimeMs: 12,
            requiresConfirmation: true,
            pendingApprovalId: approvalId
        )
        let pendingApproval = PendingApproval(
            id: approvalId,
            command: command,
            riskAssessment: RiskAssessment(
                level: .high,
                reason: "File deletion",
                affectedPaths: ["/ext/test.txt"],
                requiresDiff: false,
                requiresConfirmation: true
            ),
            sessionId: "session-approval"
        )

        let openRouterClient = MockOpenRouterClient(chatResponses: [
            .success(ChatCompletionResponse(
                content: "I will delete the file.",
                toolCalls: [toolCall],
                model: "test-model",
                usage: nil
            )),
            .success(ChatCompletionResponse(
                content: "Done.",
                toolCalls: nil,
                model: "test-model",
                usage: nil
            ))
        ])

        let commandExecutor = MockCommandExecutor(
            executeResult: approvalResult,
            approveResult: approvedCommandResult,
            rejectResult: rejectedCommandResult
        )
        commandExecutor.pendingApprovals[approvalId] = pendingApproval

        let chatStore = MockChatStore()
        let auditService = MockAuditService()
        let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: "vesper.approval.tests")!)
        let agent = VesperAgent(
            openRouterClient: openRouterClient,
            commandExecutor: commandExecutor,
            auditService: auditService,
            chatStore: chatStore,
            settingsStore: settingsStore
        )
        agent.startNewSession(deviceName: nil)

        return (agent, openRouterClient, commandExecutor, chatStore)
    }

    func testApprovalRequestPersistsPendingStateAndMetadata() async {
        let (agent, openRouterClient, commandExecutor, chatStore) = makeAgent()

        await agent.sendMessage("Please delete /ext/test.txt")

        XCTAssertEqual(commandExecutor.executedCommands.count, 1)
        XCTAssertEqual(agent.conversationState.messages.count, 2)
        XCTAssertNotNil(agent.conversationState.pendingApproval)
        XCTAssertEqual(agent.conversationState.pendingApproval?.id, "approval-123")
        XCTAssertEqual(agent.conversationState.messages.last?.metadata?.pendingApprovalId, "approval-123")
        XCTAssertFalse(agent.conversationState.isLoading)
        XCTAssertEqual(openRouterClient.recordedMessages.count, 1)
        XCTAssertEqual(chatStore.savedSessions[agent.conversationState.sessionId]?.count, 2)
    }

    func testApproveCommandResumesConversation() async {
        let (agent, openRouterClient, commandExecutor, _) = makeAgent()

        await agent.sendMessage("Please delete /ext/test.txt")
        await agent.continueAfterApproval(approvalId: "approval-123", approved: true)

        XCTAssertEqual(commandExecutor.approvedApprovalIds, ["approval-123"])
        XCTAssertNil(agent.conversationState.pendingApproval)
        XCTAssertFalse(agent.conversationState.isLoading)
        XCTAssertEqual(openRouterClient.recordedMessages.count, 2)
        XCTAssertEqual(agent.conversationState.messages.filter { $0.role == .tool }.count, 1)
        XCTAssertEqual(agent.conversationState.messages.last?.role, .assistant)
        XCTAssertEqual(agent.conversationState.messages.first(where: { $0.role == .assistant })?.metadata?.pendingApprovalId, nil)
    }

    func testDenyCommandResumesConversation() async {
        let (agent, openRouterClient, commandExecutor, _) = makeAgent()

        await agent.sendMessage("Please delete /ext/test.txt")
        await agent.continueAfterApproval(approvalId: "approval-123", approved: false)

        XCTAssertEqual(commandExecutor.rejectedApprovalIds, ["approval-123"])
        XCTAssertNil(agent.conversationState.pendingApproval)
        XCTAssertFalse(agent.conversationState.isLoading)
        XCTAssertEqual(openRouterClient.recordedMessages.count, 2)
        XCTAssertEqual(agent.conversationState.messages.last?.role, .assistant)
    }
}

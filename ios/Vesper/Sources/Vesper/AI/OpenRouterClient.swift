// OpenRouterClient.swift
// Vesper - AI-powered Flipper Zero controller
// URLSession-based HTTP client for OpenRouter API

import Foundation

// MARK: - Result Types

enum ChatCompletionResult {
    case success(ChatCompletionResponse)
    case error(String)
}

struct ChatCompletionResponse {
    let content: String?
    let toolCalls: [ToolCall]?
    let model: String
    let usage: TokenUsage?
}

struct TokenUsage {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

struct ParsedCommand {
    let command: ExecuteCommand?
    let error: String?

    init(command: ExecuteCommand? = nil, error: String? = nil) {
        self.command = command
        self.error = error
    }
}

// MARK: - Protocol

protocol OpenRouterClientProtocol: Sendable {
    func chat(messages: [ChatMessage], sessionId: String) async -> ChatCompletionResult
    func formatResult(_ result: CommandResult) -> String
    func parseCommand(from arguments: String) -> (command: ExecuteCommand?, error: String?)
}

// MARK: - OpenRouter Client

/// URLSession-based HTTP client for the OpenRouter chat completions API.
/// Handles tool-calling with the execute_command interface, rate limiting,
/// retry with exponential backoff, and response validation.
final class OpenRouterClient: @unchecked Sendable {

    private let settingsStore: SettingsStore
    private let secureStorage: SecureStorage
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    // Rate limiter: 30 requests per minute
    private let rateLimitQueue = DispatchQueue(label: "com.vesper.ratelimiter")
    private var requestTimestamps: [Date] = []
    private let maxRequests = 30
    private let windowSeconds: TimeInterval = 60

    // Retry config
    private let maxRetries = 2
    private let initialDelayMs: UInt64 = 700
    private let maxDelayMs: UInt64 = 10_000
    private let backoffMultiplier: Double = 2.0

    // Limits
    private let maxContextMessages = 24
    private let maxToolCallsPerResponse = 1
    private let toolCallResponseMaxTokens = 1024
    private let toolModelBlockQueue = DispatchQueue(label: "com.vesper.openrouter.tool-models")
    private var unsupportedToolModels: [String: Date] = [:]

    private static let toolModelFallbackCandidates = [
        "nousresearch/hermes-4-405b",
        "anthropic/claude-sonnet-4.6",
        "anthropic/claude-sonnet-4.5",
        "openai/o4-mini",
        "x-ai/grok-4-fast",
        "google/gemini-2.5-flash",
        "openai/gpt-4o-mini"
    ]

    private static let visionModelCandidates = [
        "google/gemini-2.0-flash-001",
        "google/gemini-2.5-flash",
        "openai/gpt-4o-mini"
    ]
    private static let visionSystemPrompt =
        "You are a visual analysis assistant for a Flipper Zero companion app. " +
        "Describe the image in detail. Focus on brand names, model numbers, device types, " +
        "visible text or labels, and details that would help identify the correct IR, RF, NFC, " +
        "or Bluetooth protocol. Be specific and concise."

    private static let apiURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private static let httpReferer = "https://github.com/elder-plinius/V3SP3R"
    private static let appTitle = "Vesper"

    // MARK: - Init

    init(settingsStore: SettingsStore, secureStorage: SecureStorage = SecureStorage()) {
        self.settingsStore = settingsStore
        self.secureStorage = secureStorage

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 75
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)

        self.jsonEncoder = JSONEncoder()
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase

        self.jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Public API

    /// Send a chat completion request with tool calling support.
    /// Returns parsed response with optional tool calls.
    func chat(messages: [ChatMessage], sessionId: String) async -> ChatCompletionResult {
        // Check rate limit
        if !tryAcquireRateLimit() {
            let waitTime = timeUntilRateLimitReset()
            return .error("Rate limit exceeded. Please wait \(Int(waitTime))s before trying again.")
        }

        // Load API key from Keychain
        guard let apiKey = secureStorage.loadAPIKey(), !apiKey.isEmpty else {
            return .error("OpenRouter API key not configured. Go to Settings to add your key.")
        }

        // Validate API key format
        guard isValidApiKeyFormat(apiKey) else {
            return .error("Invalid API key format. OpenRouter keys start with 'sk-or-'.")
        }

        // Trim conversation to stay within context limits
        let compactMessages = trimConversation(messages)
        let hasImages = compactMessages.contains { !($0.imageAttachments?.isEmpty ?? true) }
        let processedMessages = hasImages
            ? await preprocessImagesAsText(compactMessages, apiKey: apiKey)
            : compactMessages

        // Build system prompt with optional glasses addendum
        let systemPrompt: String
        if settingsStore.glassesEnabled {
            systemPrompt = VesperPrompts.systemPrompt + "\n\n" + VesperPrompts.smartglassesAddendum
        } else {
            systemPrompt = VesperPrompts.systemPrompt
        }

        // Build API request messages
        var requestMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        requestMessages.append(contentsOf: buildRequestMessages(from: processedMessages))

        // Select tool definition based on glasses state
        let tools: [[String: Any]]
        if settingsStore.glassesEnabled {
            tools = VesperPrompts.toolDefinition
        } else {
            tools = VesperPrompts.toolDefinitionWithoutGlasses()
        }

        let candidateModels = buildToolModelCandidates(selectedModel: settingsStore.selectedModel)
        var lastError: ChatCompletionResult?

        for candidateModel in candidateModels {
            if isToolModelTemporarilyBlocked(candidateModel) {
                continue
            }

            let requestBody: [String: Any] = [
                "model": candidateModel,
                "messages": requestMessages,
                "tools": tools,
                "tool_choice": "auto",
                "max_tokens": toolCallResponseMaxTokens
            ]

            guard let httpRequest = buildHTTPRequest(apiKey: apiKey, body: requestBody) else {
                return .error("Failed to build API request")
            }

            let result = await executeWithRetry(request: httpRequest)
            switch result {
            case .success:
                markToolModelWorking(candidateModel)
                return result

            case .error(let message):
                lastError = result

                if isToolUseUnsupportedError(message) {
                    markToolModelUnsupported(candidateModel)
                    continue
                }

                if isModelAvailabilityError(message) {
                    continue
                }

                if isToolPairingError(message) {
                    return .error("Tool-call history is out of sync for this conversation. Start a new chat session and retry.")
                }

                return result
            }
        }

        return lastError ?? .error("Unable to find a working model for tool execution.")
    }

    /// Format a CommandResult as JSON string for sending back to the AI as a tool result.
    func formatResult(_ result: CommandResult) -> String {
        if let data = try? jsonEncoder.encode(result),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        if result.success {
            return """
            {"success": true, "action": "\(result.action.rawValue)", "data": {"message": "\(result.data?.message ?? "Done")"}}
            """
        } else {
            return """
            {"success": false, "action": "\(result.action.rawValue)", "error": "\(result.error ?? "Unknown error")"}
            """
        }
    }

    /// Parse an ExecuteCommand from tool call arguments JSON.
    func parseCommand(from arguments: String) -> (command: ExecuteCommand?, error: String?) {
        let parsed = parseCommandDetailed(arguments)
        return (parsed.command, parsed.error)
    }

    func parseCommandDetailed(_ arguments: String) -> ParsedCommand {
        let trimmed = stripCodeFences(arguments.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty else {
            return ParsedCommand(error: "Tool arguments were empty. Expected format: {\"action\":\"...\",\"args\":{...}}")
        }

        guard let data = trimmed.data(using: .utf8) else {
            return ParsedCommand(error: "Invalid UTF-8 in tool arguments")
        }

        let strictDecoder = JSONDecoder()
        strictDecoder.keyDecodingStrategy = .convertFromSnakeCase
        if let command = try? strictDecoder.decode(ExecuteCommand.self, from: data) {
            return ParsedCommand(command: command)
        }

        guard let raw = try? JSONSerialization.jsonObject(with: data) else {
            return ParsedCommand(error: "Could not parse tool arguments as JSON. Expected: {\"action\":\"...\",\"args\":{...}}")
        }

        let rootObject: [String: Any]
        if let array = raw as? [[String: Any]], let first = array.first {
            rootObject = first
        } else if let dict = raw as? [String: Any] {
            rootObject = dict
        } else {
            return ParsedCommand(error: "Tool arguments must be a JSON object, got \(type(of: raw)).")
        }

        guard let actionString = stringValue(rootObject, keys: "action") else {
            return ParsedCommand(error: "Missing 'action' field in tool arguments")
        }

        guard let action = parseCommandAction(actionString) else {
            return ParsedCommand(error: "Unknown action: '\(actionString)'. Check spelling and use snake_case.")
        }

        let argsObject = extractArgsObject(from: rootObject)
        let args = CommandArgs(
            command: stringValue(argsObject, keys: "command", "query", "app_id", "appId", "app", "name"),
            path: stringValue(argsObject, keys: "path", "file_path", "filepath"),
            destinationPath: stringValue(argsObject, keys: "destination_path", "destinationPath", "dest", "destination"),
            content: stringValue(argsObject, keys: "content", "text", "data"),
            newName: stringValue(argsObject, keys: "new_name", "newName"),
            recursive: boolValue(argsObject, keys: "recursive", "is_recursive") ?? false,
            artifactType: stringValue(argsObject, keys: "artifact_type", "artifactType"),
            artifactData: stringValue(argsObject, keys: "artifact_data", "artifactData", "data_base64"),
            prompt: stringValue(argsObject, keys: "prompt", "description", "forge_prompt"),
            resourceType: stringValue(argsObject, keys: "resource_type", "resourceType", "type"),
            runbookId: stringValue(argsObject, keys: "runbook_id", "runbookId", "runbook"),
            payloadType: stringValue(argsObject, keys: "payload_type", "payloadType"),
            filter: stringValue(argsObject, keys: "filter", "vault_filter"),
            appName: stringValue(argsObject, keys: "app_name", "appName"),
            appArgs: stringValue(argsObject, keys: "app_args", "appArgs", "app_arguments"),
            frequency: int64Value(argsObject, keys: "frequency", "freq"),
            protocol: stringValue(argsObject, keys: "protocol"),
            address: stringValue(argsObject, keys: "address"),
            signalName: stringValue(argsObject, keys: "signal_name", "signalName", "signal"),
            enabled: boolValue(argsObject, keys: "enabled", "on"),
            red: intValue(argsObject, keys: "red", "r"),
            green: intValue(argsObject, keys: "green", "g"),
            blue: intValue(argsObject, keys: "blue", "b"),
            repoId: stringValue(argsObject, keys: "repo_id", "repoId", "repo"),
            subPath: stringValue(argsObject, keys: "sub_path", "subPath"),
            downloadUrl: stringValue(argsObject, keys: "download_url", "downloadUrl", "url"),
            searchScope: stringValue(argsObject, keys: "search_scope", "searchScope", "scope"),
            photoPrompt: stringValue(argsObject, keys: "photo_prompt", "photoPrompt")
        )

        let justification = stringValue(rootObject, keys: "justification") ?? "Tool call requested by AI"
        let expectedEffect = stringValue(rootObject, keys: "expected_effect") ?? "Execute requested operation safely."
        return ParsedCommand(
            command: ExecuteCommand(
                action: action,
                args: args,
                justification: justification,
                expectedEffect: expectedEffect
            )
        )
    }

    // MARK: - Image Preprocessing

    internal func preprocessImagesAsText(_ messages: [ChatMessage], apiKey: String) async -> [ChatMessage] {
        guard !messages.isEmpty else { return messages }

        return await withTaskGroup(of: (Int, ChatMessage).self) { group in
            for (index, message) in messages.enumerated() {
                group.addTask { [self] in
                    (index, await self.preprocessImageMessage(message, apiKey: apiKey))
                }
            }

            var processed = Array(repeating: messages[0], count: messages.count)
            for await (index, message) in group {
                processed[index] = message
            }
            return processed
        }
    }

    private func describeImage(apiKey: String, attachment: ImageAttachment) async -> String? {
        for model in Self.visionModelCandidates {
            if let description = try? await requestVisionDescription(
                apiKey: apiKey,
                model: model,
                attachment: attachment
            ),
            !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return description.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func requestVisionDescription(
        apiKey: String,
        model: String,
        attachment: ImageAttachment
    ) async throws -> String {
        let imageData = attachment.data.base64EncodedString()
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": Self.visionSystemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Describe this image for a Flipper Zero assistant."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:\(attachment.mimeType);base64,\(imageData)",
                                "detail": "auto"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 256
        ]

        guard let request = buildHTTPRequest(apiKey: apiKey, body: requestBody) else {
            throw NSError(domain: "OpenRouterClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to build vision request"])
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenRouterClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid vision response"])
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenRouterClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Vision API error \(httpResponse.statusCode): \(body.prefix(200))"])
        }

        switch parseResponse(data: data) {
        case .success(let response):
            return response.content ?? ""
        case .error(let message):
            throw NSError(domain: "OpenRouterClient", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // MARK: - Tool-Model Fallback

    private func buildToolModelCandidates(selectedModel: String) -> [String] {
        let candidates = [selectedModel] + Self.toolModelFallbackCandidates
        var unique: [String] = []
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !trimmed.lowercased().contains("gemini-2.5-flash-image-preview") else { continue }
            guard !unique.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { continue }
            unique.append(trimmed)
            if unique.count >= 10 { break }
        }
        return unique
    }

    private func isToolModelTemporarilyBlocked(_ model: String) -> Bool {
        toolModelBlockQueue.sync {
            guard let blockedAt = unsupportedToolModels[model] else { return false }
            if Date().timeIntervalSince(blockedAt) > 5 * 60 {
                unsupportedToolModels.removeValue(forKey: model)
                return false
            }
            return true
        }
    }

    private func markToolModelUnsupported(_ model: String) {
        toolModelBlockQueue.sync {
            unsupportedToolModels[model] = Date()
        }
    }

    private func markToolModelWorking(_ model: String) {
        toolModelBlockQueue.sync {
            unsupportedToolModels.removeValue(forKey: model)
        }
    }

    private func isToolUseUnsupportedError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("tool use is not supported") ||
            normalized.contains("tool use not supported") ||
            normalized.contains("tool_calls") && normalized.contains("unsupported") ||
            normalized.contains("tools not supported") ||
            normalized.contains("does not support tools")
    }

    private func isModelAvailabilityError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("model not found") ||
            normalized.contains("provider not found") ||
            normalized.contains("not available for your account") ||
            normalized.contains("you are not allowed to use this model") ||
            normalized.contains("access denied")
    }

    private func isToolPairingError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("tool use block must have a corresponding tool use block in previous message") ||
            normalized.contains("tool_result blocks") ||
            normalized.contains("tool_use blocks") ||
            normalized.contains("tool use ids were found without tool_result blocks")
    }

    private func stripCodeFences(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else { return trimmed }

        let bodyLines = lines.dropFirst().dropLast()
        let body = bodyLines.joined(separator: "\n")
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeActionName(_ action: String) -> String {
        action
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"([a-z])([A-Z])"#, with: "$1_$2", options: .regularExpression)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private func parseCommandAction(_ action: String) -> CommandAction? {
        let normalized = normalizeActionName(action)
        switch normalized {
        case "list_directory":
            return .listDirectory
        case "read_file":
            return .readFile
        case "write_file":
            return .writeFile
        case "create_directory":
            return .createDirectory
        case "delete":
            return .delete
        case "move":
            return .move
        case "rename":
            return .rename
        case "copy":
            return .copy
        case "get_device_info":
            return .getDeviceInfo
        case "get_storage_info":
            return .getStorageInfo
        case "execute_cli", "execute_command", "run_command", "cli_command", "command", "send_command":
            return .executeCli
        case "push_artifact":
            return .pushArtifact
        case "forge_payload", "forge", "craft_payload", "create_payload":
            return .forgePayload
        case "subghz_transmit":
            return .subghzTransmit
        case "ir_transmit":
            return .irTransmit
        case "nfc_emulate":
            return .nfcEmulate
        case "rfid_emulate":
            return .rfidEmulate
        case "ibutton_emulate":
            return .ibuttonEmulate
        case "badusb_execute":
            return .badusbExecute
        case "ble_spam":
            return .bleSpam
        case "launch_app", "open_app", "start_app", "loader_open":
            return .launchApp
        case "led_control":
            return .ledControl
        case "vibro_control":
            return .vibroControl
        case "search_faphub", "faphub_search", "find_faphub":
            return .searchFaphub
        case "install_faphub_app", "install_faphub", "faphub_install":
            return .installFaphubApp
        case "browse_repo", "browse_repository", "list_repo", "repo_browse", "repo_contents":
            return .browseRepo
        case "download_resource", "download_file", "fetch_resource", "get_resource":
            return .downloadResource
        case "github_search", "search_github", "gh_search", "find_on_github":
            return .githubSearch
        case "search_resources", "browse_resources", "find_resources":
            return .searchResources
        case "list_vault", "vault", "scan_vault", "inventory":
            return .listVault
        case "run_runbook", "runbook", "diagnostic":
            return .runRunbook
        case "request_photo":
            return .requestPhoto
        default:
            return CommandAction(rawValue: normalized)
        }
    }

    private func extractArgsObject(from rootObject: [String: Any]) -> [String: Any] {
        if let dict = rootObject["args"] as? [String: Any] {
            return dict
        }
        if let dict = rootObject["parameters"] as? [String: Any] {
            return dict
        }
        if let string = rootObject["args"] as? String,
           let data = string.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parsed
        }
        if let array = rootObject["args"] as? [[String: Any]], let first = array.first {
            return first
        }
        return rootObject
    }

    private func stringValue(_ dictionary: [String: Any], keys: String...) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty {
                return value
            }
            if let value = dictionary[key] as? NSNumber {
                return value.stringValue
            }
        }
        return nil
    }

    private func boolValue(_ dictionary: [String: Any], keys: String...) -> Bool? {
        for key in keys {
            if let value = dictionary[key] as? Bool {
                return value
            }
            if let value = dictionary[key] as? NSNumber {
                return value.boolValue
            }
            if let value = dictionary[key] as? String {
                switch value.lowercased() {
                case "true", "1", "yes": return true
                case "false", "0", "no": return false
                default: break
                }
            }
        }
        return nil
    }

    private func intValue(_ dictionary: [String: Any], keys: String...) -> Int? {
        for key in keys {
            if let value = dictionary[key] as? Int {
                return value
            }
            if let value = dictionary[key] as? NSNumber {
                return value.intValue
            }
            if let value = dictionary[key] as? String, let parsed = Int(value) {
                return parsed
            }
        }
        return nil
    }

    private func int64Value(_ dictionary: [String: Any], keys: String...) -> Int64? {
        for key in keys {
            if let value = dictionary[key] as? Int64 {
                return value
            }
            if let value = dictionary[key] as? Int {
                return Int64(value)
            }
            if let value = dictionary[key] as? NSNumber {
                return value.int64Value
            }
            if let value = dictionary[key] as? String, let parsed = Int64(value) {
                return parsed
            }
        }
        return nil
    }

    private func preprocessImageMessage(_ message: ChatMessage, apiKey: String) async -> ChatMessage {
        guard let attachments = message.imageAttachments, !attachments.isEmpty else {
            return message
        }

        let descriptions = await withTaskGroup(of: String?.self) { group in
            for attachment in attachments {
                group.addTask { [self] in
                    await self.describeImage(apiKey: apiKey, attachment: attachment)
                }
            }

            var results: [String] = []
            for await description in group {
                if let description, !description.isEmpty {
                    results.append(description)
                }
            }
            return results
        }

        if descriptions.isEmpty {
            let failNote = "[\(attachments.count) image(s) were attached but could not be analyzed. Ask the user to try again or describe what they see.]"
            let fallbackContent: String
            if let content = message.content, !content.isEmpty {
                fallbackContent = "\(failNote)\n\n\(content)"
            } else {
                fallbackContent = failNote
            }
            return ChatMessage(
                id: message.id,
                role: message.role,
                content: fallbackContent,
                timestamp: message.timestamp,
                toolCalls: message.toolCalls,
                toolResults: message.toolResults,
                imageAttachments: nil,
                isError: message.isError
            )
        }

        let context = descriptions.map { "[Attached image: \($0)]" }.joined(separator: "\n")
        let updatedContent: String
        if let content = message.content, !content.isEmpty {
            updatedContent = "\(context)\n\n\(content)"
        } else {
            updatedContent = context
        }

        return ChatMessage(
            id: message.id,
            role: message.role,
            content: updatedContent,
            timestamp: message.timestamp,
            toolCalls: message.toolCalls,
            toolResults: message.toolResults,
            imageAttachments: nil,
            isError: message.isError
        )
    }

    // MARK: - Rate Limiting

    private func tryAcquireRateLimit() -> Bool {
        rateLimitQueue.sync {
            let now = Date()
            let windowStart = now.addingTimeInterval(-windowSeconds)
            requestTimestamps.removeAll { $0 < windowStart }
            if requestTimestamps.count >= maxRequests {
                return false
            }
            requestTimestamps.append(now)
            return true
        }
    }

    private func timeUntilRateLimitReset() -> TimeInterval {
        rateLimitQueue.sync {
            guard let oldest = requestTimestamps.first else { return 0 }
            let resetTime = oldest.addingTimeInterval(windowSeconds)
            return max(0, resetTime.timeIntervalSinceNow)
        }
    }

    // MARK: - API Key Validation

    private func isValidApiKeyFormat(_ key: String) -> Bool {
        // OpenRouter keys typically start with "sk-or-" and are at least 20 chars
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 20 && (trimmed.hasPrefix("sk-or-") || trimmed.hasPrefix("sk-"))
    }

    // MARK: - Request Building

    private func buildHTTPRequest(apiKey: String, body: [String: Any]) -> URLRequest? {
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }

        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.httpReferer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(Self.appTitle, forHTTPHeaderField: "X-Title")
        request.httpBody = bodyData

        return request
    }

    private func buildRequestMessages(from messages: [ChatMessage]) -> [[String: Any]] {
        var result: [[String: Any]] = []

        for message in messages {
            switch message.role {
            case .user:
                if let attachments = message.imageAttachments, !attachments.isEmpty {
                    // Multimodal message with images
                    var contentParts: [[String: Any]] = []
                    if !(message.content?.isEmpty ?? true) {
                        contentParts.append([
                            "type": "text",
                            "text": message.content
                        ])
                    }
                    for attachment in attachments {
                        let base64 = attachment.data.base64EncodedString()
                        contentParts.append([
                            "type": "image_url",
                            "image_url": [
                                "url": "data:\(attachment.mimeType);base64,\(base64)",
                                "detail": "auto"
                            ]
                        ])
                    }
                    result.append([
                        "role": "user",
                        "content": contentParts
                    ])
                } else {
                    result.append([
                        "role": "user",
                        "content": message.content
                    ])
                }

            case .assistant:
                var msg: [String: Any] = [
                    "role": "assistant",
                    "content": message.content
                ]
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    msg["tool_calls"] = toolCalls.map { tc in
                        [
                            "id": tc.id,
                            "type": "function",
                            "function": [
                                "name": tc.name,
                                "arguments": tc.arguments
                            ]
                        ] as [String: Any]
                    }
                }
                result.append(msg)

            case .tool:
                if let toolResults = message.toolResults {
                    for tr in toolResults {
                        result.append([
                            "role": "tool",
                            "tool_call_id": tr.toolCallId,
                            "content": tr.content
                        ])
                    }
                }

            case .system:
                result.append([
                    "role": "system",
                    "content": message.content
                ])
            }
        }

        return result
    }

    private func trimConversation(_ messages: [ChatMessage]) -> [ChatMessage] {
        if messages.count <= maxContextMessages {
            return messages
        }
        // Keep the first message (if it contains user context) and the last N messages
        let tail = Array(messages.suffix(maxContextMessages))
        return tail
    }

    // MARK: - Request Execution

    private func executeWithRetry(request: URLRequest) async -> ChatCompletionResult {
        var lastError: String?
        var delayMs = initialDelayMs

        for attempt in 0..<(maxRetries + 1) {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = "Invalid response type"
                    continue
                }

                // Rate limit from server
                if httpResponse.statusCode == 429 {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { UInt64($0) } ?? 60
                    try await Task.sleep(nanoseconds: retryAfter * 1_000_000_000)
                    continue
                }

                // Server errors (5xx) are retryable
                if (500...599).contains(httpResponse.statusCode) {
                    lastError = "Server error: \(httpResponse.statusCode)"
                    if attempt < maxRetries {
                        try await Task.sleep(nanoseconds: delayMs * 1_000_000)
                        delayMs = min(UInt64(Double(delayMs) * backoffMultiplier), maxDelayMs)
                    }
                    continue
                }

                // Client errors (4xx except 429) are not retryable
                if !(200...299).contains(httpResponse.statusCode) {
                    let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                    return .error("API error \(httpResponse.statusCode): \(body.prefix(500))")
                }

                // Parse successful response
                return parseResponse(data: data)

            } catch is CancellationError {
                return .error("Request cancelled")
            } catch let urlError as URLError {
                if urlError.code == .notConnectedToInternet || urlError.code == .cannotFindHost {
                    return .error("No internet connection. Check your network and try again.")
                }
                lastError = urlError.localizedDescription
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
                    delayMs = min(UInt64(Double(delayMs) * backoffMultiplier), maxDelayMs)
                }
            } catch {
                lastError = error.localizedDescription
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
                    delayMs = min(UInt64(Double(delayMs) * backoffMultiplier), maxDelayMs)
                }
            }
        }

        return .error("Request failed after \(maxRetries + 1) attempts: \(lastError ?? "unknown error")")
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data) -> ChatCompletionResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .error("Invalid JSON in API response")
        }

        // Check for error envelope
        if let errorObj = json["error"] as? [String: Any] {
            let message = errorObj["message"] as? String ?? "Unknown API error"
            let code = errorObj["code"] as? Int
            let prefix = code.map { "API error \($0)" } ?? "API error"
            return .error("\(prefix): \(message)")
        }

        // Extract choices
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            return .error("No choices in API response")
        }

        // Extract content
        let content: String?
        if let contentString = message["content"] as? String {
            content = contentString
        } else if let contentArray = message["content"] as? [[String: Any]] {
            // Handle array-of-parts format
            content = contentArray.compactMap { part -> String? in
                if part["type"] as? String == "text" {
                    return part["text"] as? String
                }
                return nil
            }.joined(separator: "\n")
        } else {
            content = nil
        }

        // Extract tool calls
        var toolCalls: [ToolCall]?
        if let rawToolCalls = message["tool_calls"] as? [[String: Any]] {
            toolCalls = rawToolCalls.compactMap { tc -> ToolCall? in
                guard let id = tc["id"] as? String, !id.isEmpty,
                      let function = tc["function"] as? [String: Any],
                      let name = function["name"] as? String, !name.isEmpty,
                      let arguments = function["arguments"] as? String else {
                    return nil
                }
                return ToolCall(id: id, name: name, arguments: arguments)
            }
            // Limit tool calls per response
            if let calls = toolCalls, calls.count > maxToolCallsPerResponse {
                toolCalls = Array(calls.prefix(maxToolCallsPerResponse))
            }
            if toolCalls?.isEmpty == true {
                toolCalls = nil
            }
        }

        // Extract model name
        let modelName = json["model"] as? String ?? "unknown"

        // Extract usage
        var usage: TokenUsage?
        if let usageDict = json["usage"] as? [String: Any] {
            let prompt = usageDict["prompt_tokens"] as? Int ?? 0
            let completion = usageDict["completion_tokens"] as? Int ?? 0
            let total = usageDict["total_tokens"] as? Int ?? (prompt + completion)
            usage = TokenUsage(
                promptTokens: prompt,
                completionTokens: completion,
                totalTokens: total
            )
        }

        let response = ChatCompletionResponse(
            content: content,
            toolCalls: toolCalls,
            model: modelName,
            usage: usage
        )

        return .success(response)
    }
}

extension OpenRouterClient: OpenRouterClientProtocol {}

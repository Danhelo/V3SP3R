import SwiftUI

@Observable
class SettingsViewModel {
    private let settingsStore: SettingsStore
    private let secureStorage: SecureStorage

    var apiKey: String = ""
    var apiKeyMasked: String = ""
    var hasApiKey: Bool = false
    var selectedModel: String = ""
    var autoApproveMedium: Bool = false
    var autoApproveHigh: Bool = false
    var glassesEnabled: Bool = false
    var glassesBridgeUrl: String = ""
    var showApiKeyField: Bool = false
    var saveError: String?

    static let availableModels: [(id: String, name: String)] = [
        // Top tier — best tool calling
        ("nousresearch/hermes-4-405b", "Hermes 4 405B"),
        ("anthropic/claude-sonnet-4.6", "Claude Sonnet 4.6"),
        ("anthropic/claude-opus-4.6", "Claude Opus 4.6"),
        ("anthropic/claude-sonnet-4.5", "Claude Sonnet 4.5"),
        ("google/gemini-2.5-flash", "Gemini 2.5 Flash"),
        ("google/gemini-2.5-pro", "Gemini 2.5 Pro"),
        ("openai/o4-mini", "OpenAI o4 Mini"),
        // Strong alternatives
        ("deepseek/deepseek-v3.2", "DeepSeek V3.2"),
        ("x-ai/grok-4-fast", "Grok 4 Fast"),
        ("meta-llama/llama-4-maverick-17b-128e-instruct", "Llama 4 Maverick"),
        ("mistralai/devstral-medium-2507", "Devstral Medium"),
        ("deepseek/deepseek-r1", "DeepSeek R1"),
    ]

    init(settingsStore: SettingsStore, secureStorage: SecureStorage) {
        self.settingsStore = settingsStore
        self.secureStorage = secureStorage
        loadSettings()
    }

    func loadSettings() {
        selectedModel = settingsStore.selectedModel
        autoApproveMedium = settingsStore.autoApproveMedium
        autoApproveHigh = settingsStore.autoApproveHigh
        glassesEnabled = settingsStore.glassesEnabled
        glassesBridgeUrl = settingsStore.glassesBridgeUrl

        if let key = secureStorage.loadAPIKey() {
            hasApiKey = true
            apiKeyMasked = maskApiKey(key)
        }
    }

    func saveApiKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try secureStorage.saveAPIKey(trimmed)
            hasApiKey = true
            apiKeyMasked = maskApiKey(trimmed)
            apiKey = ""
            showApiKeyField = false
            saveError = nil
        } catch {
            saveError = "Failed to save API key: \(error.localizedDescription)"
        }
    }

    func deleteApiKey() {
        do {
            try secureStorage.deleteAPIKey()
            hasApiKey = false
            apiKeyMasked = ""
            apiKey = ""
            saveError = nil
        } catch {
            saveError = "Failed to delete API key: \(error.localizedDescription)"
        }
    }

    func saveModel() {
        settingsStore.selectedModel = selectedModel
    }

    func saveAutoApprove() {
        settingsStore.autoApproveMedium = autoApproveMedium
        settingsStore.autoApproveHigh = autoApproveHigh
    }

    func saveGlassesSettings() {
        settingsStore.glassesEnabled = glassesEnabled
        settingsStore.glassesBridgeUrl = glassesBridgeUrl
    }

    private func maskApiKey(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "*", count: key.count) }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }
}

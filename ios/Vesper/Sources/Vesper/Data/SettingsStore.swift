// SettingsStore.swift
// Vesper - AI-powered Flipper Zero controller
// UserDefaults-backed observable settings store

import Foundation
import Observation

/// Observable settings store backed by UserDefaults.
/// Properties are read/written synchronously and publish changes through the Observation framework.
@Observable
final class SettingsStore: SettingsStoreProtocol, @unchecked Sendable {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let selectedModel = "vesper_selected_model"
        static let autoApproveMedium = "vesper_auto_approve_medium"
        static let autoApproveHigh = "vesper_auto_approve_high"
        static let glassesEnabled = "vesper_glasses_enabled"
        static let glassesBridgeUrl = "vesper_glasses_bridge_url"
        static let protectedPathsUnlocked = "vesper_protected_paths_unlocked"
        static let allowedPathScopes = "vesper_allowed_path_scopes"
    }

    // MARK: - Defaults

    static let defaultModel = "nousresearch/hermes-4-405b"

    // MARK: - Storage

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load initial values from UserDefaults
        _selectedModel = defaults.string(forKey: Keys.selectedModel) ?? Self.defaultModel
        _autoApproveMedium = defaults.bool(forKey: Keys.autoApproveMedium)
        _autoApproveHigh = defaults.bool(forKey: Keys.autoApproveHigh)
        _glassesEnabled = defaults.bool(forKey: Keys.glassesEnabled)
        _glassesBridgeUrl = defaults.string(forKey: Keys.glassesBridgeUrl) ?? ""

        if let saved = defaults.stringArray(forKey: Keys.protectedPathsUnlocked) {
            _protectedPathsUnlocked = Set(saved)
        } else {
            _protectedPathsUnlocked = []
        }

        if let saved = defaults.stringArray(forKey: Keys.allowedPathScopes) {
            _allowedPathScopes = Self.normalizeScopeSet(Set(saved))
        } else {
            _allowedPathScopes = []
        }
    }

    // MARK: - Properties

    var selectedModel: String {
        get { _selectedModel }
        set {
            _selectedModel = newValue
            defaults.set(newValue, forKey: Keys.selectedModel)
        }
    }

    var autoApproveMedium: Bool {
        get { _autoApproveMedium }
        set {
            _autoApproveMedium = newValue
            defaults.set(newValue, forKey: Keys.autoApproveMedium)
        }
    }

    var autoApproveHigh: Bool {
        get { _autoApproveHigh }
        set {
            _autoApproveHigh = newValue
            defaults.set(newValue, forKey: Keys.autoApproveHigh)
        }
    }

    var glassesEnabled: Bool {
        get { _glassesEnabled }
        set {
            _glassesEnabled = newValue
            defaults.set(newValue, forKey: Keys.glassesEnabled)
        }
    }

    var glassesBridgeUrl: String {
        get { _glassesBridgeUrl }
        set {
            _glassesBridgeUrl = newValue
            defaults.set(newValue, forKey: Keys.glassesBridgeUrl)
        }
    }

    var protectedPathsUnlocked: Set<String> {
        get { _protectedPathsUnlocked }
        set {
            _protectedPathsUnlocked = newValue
            defaults.set(Array(newValue), forKey: Keys.protectedPathsUnlocked)
        }
    }

    var allowedPathScopes: Set<String> {
        get { _allowedPathScopes }
        set {
            _allowedPathScopes = Self.normalizeScopeSet(newValue)
            defaults.set(Array(_allowedPathScopes), forKey: Keys.allowedPathScopes)
        }
    }

    // MARK: - Backing Storage (tracked by @Observable)

    private var _selectedModel: String
    private var _autoApproveMedium: Bool
    private var _autoApproveHigh: Bool
    private var _glassesEnabled: Bool
    private var _glassesBridgeUrl: String
    private var _protectedPathsUnlocked: Set<String>
    private var _allowedPathScopes: Set<String>

    // MARK: - Protected Path Helpers

    /// Returns whether a specific protected path has been unlocked by the user.
    func isProtectedPathUnlocked(_ path: String) -> Bool {
        protectedPathsUnlocked.contains(path)
    }

    /// Unlocks a protected path, allowing operations on it.
    func unlockProtectedPath(_ path: String) {
        var paths = protectedPathsUnlocked
        paths.insert(path)
        protectedPathsUnlocked = paths
    }

    /// Re-locks a previously unlocked protected path.
    func lockProtectedPath(_ path: String) {
        var paths = protectedPathsUnlocked
        paths.remove(path)
        protectedPathsUnlocked = paths
    }

    /// Returns whether a path is within the user's permitted scope.
    /// By default, no scope is granted. Callers must explicitly grant a path
    /// scope to mirror Android's permission service behavior.
    func isPathInScope(_ path: String) -> Bool {
        let candidatePath = normalizeScopePath(path)
        return allowedPathScopes.contains(where: { scope in
            matchesScope(scope, path: candidatePath)
        })
    }

    /// Grants an explicit path scope for file and directory operations.
    func grantPathScope(_ path: String) {
        let normalized = normalizeScopePath(path)
        guard !normalized.isEmpty else { return }

        var scopes = allowedPathScopes
        scopes.insert(normalized)
        allowedPathScopes = scopes
    }

    /// Revokes an explicit path scope.
    func revokePathScope(_ path: String) {
        let normalized = normalizeScopePath(path)
        guard !normalized.isEmpty else { return }

        var scopes = allowedPathScopes
        scopes.remove(normalized)
        allowedPathScopes = scopes
    }

    private func normalizeScopePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else { return trimmed }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private static func normalizeScopeSet(_ scopes: Set<String>) -> Set<String> {
        Set(scopes.map { scope in
            let trimmed = scope.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count > 1 else { return trimmed }
            return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        }.filter { !$0.isEmpty })
    }

    private func matchesScope(_ scope: String, path: String) -> Bool {
        let normalizedScope = normalizeScopePath(scope)
        guard !normalizedScope.isEmpty else { return false }
        if path == normalizedScope {
            return true
        }
        return path.hasPrefix(normalizedScope + "/")
    }
}

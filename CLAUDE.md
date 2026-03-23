# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

V3SP3R (Vesper) is an AI-powered Flipper Zero controller. The Android app (Kotlin/Compose) is the original; the iOS port (SwiftUI) on `feature/ios-swiftui-port` is a one-shot layer-by-layer port done by Pliny. Both share identical architecture and risk-gating logic.

**CRITICAL: This iOS project is a PORT of the Android app. The Android codebase is the source of truth. When implementing or fixing ANY functionality on iOS, ALWAYS read the corresponding Android implementation first and match its behavior exactly.** The Android files are in `app/src/main/java/com/vesper/flipper/`.

### Android Reference Index (source of truth for iOS port)
| iOS File | Android Equivalent |
|---|---|
| `BLE/FlipperBLEManager.swift` | `ble/FlipperBleService.kt` |
| `BLE/FlipperProtocol.swift` | `ble/FlipperProtocol.kt` |
| `BLE/FlipperFileSystem.swift` | `ble/FlipperFileSystem.kt` |
| `Domain/CommandExecutor.swift` | `domain/CommandExecutor.kt` |
| `Domain/RiskAssessor.swift` | `domain/RiskAssessor.kt` |
| `Domain/InputValidator.swift` | `domain/InputValidator.kt` |
| `AI/VesperAgent.swift` | `ai/VesperAgent.kt` |
| `AI/OpenRouterClient.swift` | `ai/OpenRouterClient.kt` |
| `AI/VesperPrompts.swift` | `ai/VesperPrompts.kt` |
| `UI/Chat/ChatViewModel.swift` | `ui/viewmodel/ChatViewModel.kt` |
| `UI/FapHub/FapHubViewModel.swift` | `ui/viewmodel/FapHubViewModel.kt` |
| `UI/PayloadLab/PayloadLabViewModel.swift` | `ui/viewmodel/PayloadLabViewModel.kt` |
| `UI/AlchemyLab/AlchemyLabViewModel.swift` | `ui/viewmodel/AlchemyLabViewModel.kt` |
| `UI/SignalArsenal/SignalArsenalViewModel.swift` | `ui/viewmodel/SignalArsenalViewModel.kt` |
| `UI/SpectralOracle/SpectralOracleViewModel.swift` | `ui/viewmodel/SpectralOracleViewModel.kt` |
| `UI/DeviceTracker/DeviceTrackerViewModel.swift` | `ui/viewmodel/DeviceTrackerViewModel.kt` |
| `UI/ChimeraLab/ChimeraLabViewModel.swift` | `ui/viewmodel/ChimeraLabViewModel.kt` |
| `UI/OpsCenter/OpsCenterViewModel.swift` | `ui/viewmodel/OpsCenterViewModel.kt` |
| `Data/SettingsStore.swift` | `data/SettingsStore.kt` |
| `Data/Models.swift` | `data/Models.kt` |

## Build & Test

### Android
```bash
./gradlew assembleDebug          # Build APK
./gradlew test                   # Run unit tests
```

### iOS (SwiftUI port)
```bash
cd ios/Vesper
# swift build does NOT work — compiles for macOS host, but this is iOS-only
xcodebuild build -scheme Vesper -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -scheme Vesper -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
# Or open ios/Vesper/Package.swift in Xcode → build for iOS Simulator
```

## Architecture — "Model Decides, OS Enforces"

The AI model never touches BLE or device primitives directly. It only issues structured `ExecuteCommand` objects (action + args). The OS-side `CommandExecutor` risk-gates every command before execution.

### Layer Stack (both platforms)
```
UI (SwiftUI / Compose)
  → Domain (RiskAssessor → CommandExecutor → AuditService)
    → AI (VesperAgent → OpenRouterClient → VesperPrompts)
    → BLE (FlipperBLEManager → FlipperProtocol → FlipperFileSystem)
    → Voice (SpeechRecognizer, TTSService)
    → Glasses (GlassesBridgeClient → mentra-bridge WebSocket)
  → Data (Models, SecureStorage, SettingsStore, ChatStore, AuditStore)
```

### Command Flow
1. User message → VesperAgent → OpenRouter API (tool-calling)
2. Model returns `execute_command` tool calls
3. InputValidator sanitizes, RiskAssessor classifies (LOW/MEDIUM/HIGH/BLOCKED)
4. CommandExecutor gates: LOW auto-executes, MEDIUM shows diff + confirm, HIGH double-confirm, BLOCKED requires Settings unlock
5. Result fed back to model for up to 10 iterations
6. Every action logged to AuditService

### DI Mapping
| Android | iOS |
|---------|-----|
| Hilt @Injectable | ServiceLocator (lazy closures) |
| ViewModel + StateFlow | @Observable |
| Room | SwiftData |
| EncryptedSharedPreferences | Keychain (SecureStorage) |
| OkHttp3 | URLSession |
| BluetoothGatt + USB serial | CoreBluetooth only (no USB on iOS) |

## Non-Obvious Design Choices by Pliny

1. **Manual protobuf encoding** (`FlipperProtocol.swift`, ~1100 lines): Hand-coded wire-format encoding for the Flipper RPC subset because protoc/swift-protobuf plugin wasn't available on the build server. Wire-compatible with Android's protoc-generated code. Despite `swift-protobuf` being in Package.swift dependencies, the actual encoding is manual.

2. **All 32 CommandActions funneled through one interface**: No direct BLE calls from the agent. Every operation is a structured `ExecuteCommand` with `action: CommandAction` enum + `CommandArgs` property bag.

3. **Risk classification is line-for-line identical** between Android and iOS — treat the Android `RiskAssessor.kt` as the source of truth if they diverge.

4. **InMemoryAuditStore is the default** on iOS (SwiftData backend exists but isn't wired as default). This is intentional for simplicity but means audit logs don't persist across launches.

5. **CLI fallback**: When Flipper firmware doesn't support RPC, both platforms fall back to raw text CLI commands over the serial characteristic.

6. **Rate limiting**: OpenRouterClient enforces 30 req/min with exponential backoff retry.

## Known Issues

- `swift build` does NOT work for this project — it compiles for the macOS host, but this is iOS-only. Use `xcodebuild` with an iOS Simulator destination.
- 2 pre-existing test failures in `InputValidatorTests.testSanitizeCommandClampsColorValues` (color clamping not implemented in `sanitizeCommand`).
- `Tab` API (iOS 18+) replaced with `.tabItem` for iOS 17 compatibility.
- ServiceLocator uses `ObservableObject` (not `@Observable`) because `@Observable` doesn't support `lazy var`. Views access it via `@EnvironmentObject`.
- Protocols renamed with `Protocol` suffix (`AuditServiceProtocol`, `ChatStoreProtocol`, `FlipperFileSystemProtocol`) to avoid name collision with concrete classes.

## Key File Paths

- **Android source**: `app/src/main/java/com/vesper/flipper/`
- **iOS source**: `ios/Vesper/Sources/Vesper/` (Data/, BLE/, Domain/, AI/, Voice/, Glasses/, UI/, App/)
- **iOS tests**: `ios/Vesper/Tests/`
- **Architecture doc**: `docs/architecture.md`
- **Implementation plan**: `ios/IMPLEMENTATION_PLAN.md`
- **Mentra glasses bridge**: `mentra-bridge/` (Node.js)

## When Modifying Risk Logic

The risk classification must stay in sync across platforms. The canonical risk tiers:
- **LOW**: read-only ops, device info, catalog searches, LED/vibro
- **MEDIUM**: in-scope writes, create_directory, copy, payload gen, transmit, emulate, launch_app
- **HIGH**: delete, move, rename, badusb_execute, install_faphub_app, out-of-scope writes
- **BLOCKED**: protected system/firmware paths (require Settings unlock)

## OpenRouter Integration

Uses tool-calling (function calling) API. System prompt and tool definitions are in `VesperPrompts`. The agent loop runs up to 10 tool-call iterations per user message. Models recommended: Hermes 4, Claude Sonnet 4, Claude Opus 4.6.

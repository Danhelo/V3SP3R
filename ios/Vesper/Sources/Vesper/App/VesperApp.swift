import SwiftUI
import SwiftData

@main
struct VesperApp: App {
    @StateObject private var serviceLocator = ServiceLocator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceLocator)
        }
        .modelContainer(for: [ChatSessionEntity.self, AuditEntryEntity.self])
    }
}

/// Manual dependency injection container (replaces Hilt DI from Android)
@MainActor
class ServiceLocator: ObservableObject {
    // Data layer
    let secureStorage = SecureStorage()
    let settingsStore = SettingsStore()
    lazy var chatStore: ChatStore = {
        (try? ChatStore()) ?? ChatStore(modelContainer: try! ModelContainer(for: ChatSessionEntity.self))
    }()
    lazy var auditStoreImpl = InMemoryAuditStore()

    // BLE layer
    lazy var bleManager = FlipperBLEManager()
    lazy var flipperProtocol = FlipperProtocol(bleManager: bleManager)
    lazy var fileSystem = FlipperFileSystem(protocol: flipperProtocol)

    // Domain layer
    lazy var auditService = AuditService(store: auditStoreImpl)
    lazy var riskAssessor = RiskAssessor(settingsStore: settingsStore)
    lazy var commandExecutor = CommandExecutor(
        fileSystem: fileSystem,
        riskAssessor: riskAssessor,
        auditService: auditService,
        settingsStore: settingsStore
    )

    // AI layer
    lazy var openRouterClient = OpenRouterClient(settingsStore: settingsStore)
    lazy var payloadEngine = PayloadEngine(openRouterClient: openRouterClient, settingsStore: settingsStore)
    lazy var vesperAgent = VesperAgent(
        openRouterClient: openRouterClient,
        commandExecutor: commandExecutor,
        auditService: auditService,
        chatStore: chatStore,
        settingsStore: settingsStore
    )

    // Voice layer
    lazy var speechRecognizer = SpeechRecognizer()
    lazy var ttsService = TTSService()

    // Glasses layer
    lazy var glassesBridgeClient = GlassesBridgeClient()

    // ViewModels
    lazy var chatViewModel = ChatViewModel(
        agent: vesperAgent,
        speechRecognizer: speechRecognizer,
        ttsService: ttsService
    )
    lazy var deviceViewModel = DeviceViewModel(
        bleManager: bleManager,
        fileSystem: fileSystem
    )
    lazy var fileBrowserViewModel = FileBrowserViewModel(fileSystem: fileSystem)
    lazy var settingsViewModel = SettingsViewModel(
        settingsStore: settingsStore,
        secureStorage: secureStorage
    )
    lazy var auditLogViewModel = AuditLogViewModel(auditService: auditService)
    lazy var opsCenterViewModel = OpsCenterViewModel(
        bleManager: bleManager,
        commandExecutor: commandExecutor,
        auditService: auditService
    )
    lazy var alchemyLabViewModel = AlchemyLabViewModel(fileSystem: fileSystem)
    lazy var payloadLabViewModel = PayloadLabViewModel(
        payloadEngine: payloadEngine,
        fileSystem: fileSystem
    )
    lazy var fapHubViewModel = FapHubViewModel(commandExecutor: commandExecutor)
    lazy var resourceBrowserViewModel = ResourceBrowserViewModel(commandExecutor: commandExecutor)
}

struct ContentView: View {
    @EnvironmentObject var services: ServiceLocator

    var body: some View {
        TabView {
            NavigationStack {
                ChatView(viewModel: services.chatViewModel)
            }
            .tabItem { Label("Chat", systemImage: "message.fill") }

            NavigationStack {
                DeviceView(viewModel: services.deviceViewModel)
            }
            .tabItem { Label("Device", systemImage: "flipphone") }

            NavigationStack {
                OpsCenterView(viewModel: services.opsCenterViewModel)
            }
            .tabItem { Label("Ops", systemImage: "gauge.with.dots.needle.33percent") }

            NavigationStack {
                ToolsMenuView()
            }
            .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }

            NavigationStack {
                SettingsView(viewModel: services.settingsViewModel)
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(.purple)
    }
}

struct ToolsMenuView: View {
    @EnvironmentObject var services: ServiceLocator

    var body: some View {
        List {
            Section("Lab") {
                NavigationLink {
                    AlchemyLabView(viewModel: services.alchemyLabViewModel)
                } label: {
                    Label("Alchemy Lab", systemImage: "flask")
                }

                NavigationLink {
                    PayloadLabView(viewModel: services.payloadLabViewModel)
                } label: {
                    Label("Payload Lab", systemImage: "wand.and.stars")
                }
            }

            Section("Browse") {
                NavigationLink {
                    FileBrowserView(viewModel: services.fileBrowserViewModel)
                } label: {
                    Label("File Browser", systemImage: "folder")
                }

                NavigationLink {
                    FapHubView(viewModel: services.fapHubViewModel)
                } label: {
                    Label("FapHub", systemImage: "app.badge")
                }

                NavigationLink {
                    ResourceBrowserView(viewModel: services.resourceBrowserViewModel)
                } label: {
                    Label("Resource Browser", systemImage: "globe")
                }
            }

            Section("Security") {
                NavigationLink {
                    AuditLogView(viewModel: services.auditLogViewModel)
                } label: {
                    Label("Audit Log", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

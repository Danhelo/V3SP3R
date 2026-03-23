import SwiftUI

struct FapHubView: View {
    @Bindable var viewModel: FapHubViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            categoryBar
            Divider()

            if viewModel.displayedApps.isEmpty && viewModel.searchQuery.isEmpty && viewModel.selectedCategory == nil {
                // Initial state: show catalog browse prompt
                catalogBrowseView
            } else if viewModel.displayedApps.isEmpty {
                ContentUnavailableView {
                    Label("No Apps Found", systemImage: "magnifyingglass")
                } description: {
                    if let cat = viewModel.selectedCategory {
                        Text("No \(cat.displayName) apps match your search.")
                    } else {
                        Text("No apps match \"\(viewModel.searchQuery)\".")
                    }
                } actions: {
                    Button("Clear Filters") {
                        viewModel.clearSearch()
                    }
                }
            } else {
                appList
            }
        }
        .navigationTitle("FapHub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.refresh()
                } label: {
                    if viewModel.isLoadingInstalled {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoadingInstalled)
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "")
        }
        .alert("Confirm Action", isPresented: .init(
            get: { viewModel.pendingApproval != nil },
            set: { if !$0 { viewModel.pendingApproval = nil } }
        )) {
            if let approval = viewModel.pendingApproval {
                Button("Approve", role: .destructive) {
                    viewModel.approveInstall(approvalId: approval.approvalId, appId: approval.appId)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.denyInstall(appId: approval.appId)
                }
            }
        } message: {
            Text("This action requires confirmation because it modifies your Flipper's storage. Proceed?")
        }
        .task {
            viewModel.loadInstalledApps()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search apps...", text: $viewModel.searchQuery)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { viewModel.searchApps() }
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                categoryChip(label: "All", systemImage: "square.grid.2x2", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }

                ForEach(FapCategory.allCases) { category in
                    let count = viewModel.categoryCounts()[category] ?? 0
                    categoryChip(
                        label: "\(category.displayName) (\(count))",
                        systemImage: category.systemImage,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 4)
    }

    private func categoryChip(label: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                .clipShape(Capsule())
        }
        .tint(.primary)
    }

    // MARK: - Catalog Browse (initial state)

    private var catalogBrowseView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Installed section
                if !viewModel.installedAppIds.isEmpty {
                    installedSection
                }

                // Featured / all apps
                Section {
                    ForEach(viewModel.displayedApps.isEmpty ? FapHubCatalog.allApps : viewModel.displayedApps) { app in
                        FapAppRow(
                            app: app.withInstalled(viewModel.installedAppIds.contains(app.uid)),
                            status: viewModel.installStatuses[app.uid] ?? .idle,
                            onInstall: { viewModel.installApp(app) },
                            onUninstall: { viewModel.uninstallApp(app) }
                        )
                        Divider()
                    }
                } header: {
                    Text("All Apps")
                        .font(.headline)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - App List (filtered results)

    private var appList: some View {
        List {
            if !viewModel.installedAppIds.isEmpty && viewModel.searchQuery.isEmpty {
                installedListSection
            }

            Section(viewModel.searchQuery.isEmpty ? "Browse" : "Results (\(viewModel.displayedApps.count))") {
                ForEach(viewModel.displayedApps) { app in
                    FapAppRow(
                        app: app,
                        status: viewModel.installStatuses[app.uid] ?? .idle,
                        onInstall: { viewModel.installApp(app) },
                        onUninstall: { viewModel.uninstallApp(app) }
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Installed Section

    private var installedSection: some View {
        Section {
            let installedApps = FapHubCatalog.allApps.filter { viewModel.installedAppIds.contains($0.uid) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(installedApps) { app in
                        installedAppCard(app)
                    }
                }
                .padding(.horizontal)
            }
        } header: {
            HStack {
                Text("Installed (\(viewModel.installedAppIds.count))")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var installedListSection: some View {
        Section("Installed") {
            let installedApps = FapHubCatalog.allApps.filter { viewModel.installedAppIds.contains($0.uid) }
            if installedApps.isEmpty {
                // Some installed apps may not be in catalog
                ForEach(Array(viewModel.installedAppIds), id: \.self) { appId in
                    HStack {
                        Image(systemName: "app.badge.checkmark")
                            .foregroundStyle(.green)
                        Text(appId)
                            .font(.body)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            } else {
                ForEach(installedApps) { app in
                    FapAppRow(
                        app: app.withInstalled(true),
                        status: viewModel.installStatuses[app.uid] ?? .idle,
                        onInstall: { viewModel.installApp(app) },
                        onUninstall: { viewModel.uninstallApp(app) }
                    )
                }
            }
        }
    }

    private func installedAppCard(_ app: FapApp) -> some View {
        VStack(spacing: 4) {
            Image(systemName: app.category.systemImage)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(app.name)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 64)
        }
    }
}

// MARK: - FapAppRow

struct FapAppRow: View {
    let app: FapApp
    let status: FapInstallStatus
    let onInstall: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: app.category.systemImage)
                .font(.title2)
                .foregroundStyle(app.isInstalled ? .green : .purple)
                .frame(width: 40, height: 40)
                .background((app.isInstalled ? Color.green : Color.purple).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(app.name)
                        .font(.body.bold())
                    if app.isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Text(app.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Label(app.author, systemImage: "person")
                    Label(app.category.displayName, systemImage: "tag")
                    Label("v\(app.version)", systemImage: "number")
                    if app.downloads > 0 {
                        Label(formatDownloads(app.downloads), systemImage: "arrow.down.circle")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Action button
            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .installing:
            ProgressView()
                .controlSize(.small)

        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.red)

        case .requiresConfirmation:
            Image(systemName: "lock.shield")
                .font(.title3)
                .foregroundStyle(.orange)

        case .idle:
            if app.isInstalled {
                Button {
                    onUninstall()
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            } else {
                Button {
                    onInstall()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                }
            }
        }
    }

    private func formatDownloads(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)k"
        }
        return "\(count)"
    }
}

// MARK: - FapApp Extension

private extension FapApp {
    func withInstalled(_ installed: Bool) -> FapApp {
        var copy = self
        copy.isInstalled = installed
        return copy
    }
}

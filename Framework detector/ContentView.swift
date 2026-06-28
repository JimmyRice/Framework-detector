import SwiftUI
import AppKit

// MARK: - Content View

struct ContentView: View {
    @StateObject private var scanner = AppScanner()
    @StateObject private var upgradeManager = UpgradeManager()
    @State private var selectedFilter: FilterOption = .intel
    @State private var selectedSource: ItemSource? = nil
    @State private var searchText = ""
    @State private var includeSystemApps = false
    @State private var sortByName = true
    @State private var showUpgradeSheet = false

    private var filteredApps: [AppInfo] {
        var apps = scanner.apps
        if let category = selectedFilter.matchingCategory {
            apps = apps.filter { $0.archCategory == category }
        }
        if let src = selectedSource {
            apps = apps.filter { $0.source == src }
        }
        if !searchText.isEmpty {
            apps = apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return apps.sorted {
            sortByName
                ? $0.name.localizedCompare($1.name) == .orderedAscending
                : $0.archCategory.rawValue < $1.archCategory.rawValue
        }
    }

    private var presentSources: [ItemSource] {
        ItemSource.allCases.filter { src in scanner.apps.contains { $0.source == src } }
    }

    private var allIntelApps: [AppInfo] {
        scanner.apps.filter { $0.archCategory == .intel }
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search by name")
        .task {
            if !scanner.hasScanned { scanner.startScan(includeSystem: includeSystemApps) }
        }
        .alert("Storage Access Required", isPresented: $scanner.needsPermission) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                )
            }
            Button("Skip", role: .cancel) { }
        } message: {
            Text("Homebrew or MacPorts is detected, but the package directory cannot be read due to sandbox restrictions.\n\nPlease go to 'System Settings → Privacy & Security → Full Disk Access', add 'Architecture Detector' to the list, and click 'Rescan'.")
        }
    }

    // MARK: - Sidebar

    var sidebarView: some View {
        VStack(spacing: 0) {
            List(selection: $selectedFilter) {
                Section("Filter by Architecture") {
                    ForEach(FilterOption.allCases) { option in
                        HStack {
                            Label(option.localizedName, systemImage: option.systemImage)
                            Spacer()
                            Text("\(count(for: option))")
                                .font(.caption).monospacedDigit()
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.secondary.opacity(0.15)).clipShape(Capsule())
                        }
                        .tag(option)
                    }
                }
                Section("Scan Options") {
                    Toggle("Include System Apps (/System)", isOn: $includeSystemApps)
                        .toggleStyle(.checkbox)
                }
            }
            Divider()
            scanButtonPanel
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .navigationTitle("Architecture Detector")
    }

    var scanButtonPanel: some View {
        VStack(spacing: 8) {
            if scanner.isScanning {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                    Text(scanner.statusMessage)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                }
                Button { scanner.cancelScan() } label: {
                    Label("Stop Scanning", systemImage: "stop.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(.red).controlSize(.regular)
            } else {
                Button { scanner.startScan(includeSystem: includeSystemApps) } label: {
                    Label("Rescan", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding(12).background(.windowBackground)
    }

    // MARK: - Detail

    var detailView: some View {
        VStack(spacing: 0) {
            if scanner.isScanning { scanProgressBar }
            mainContent.frame(maxWidth: .infinity, maxHeight: .infinity)
            if !scanner.apps.isEmpty { bottomBar }
        }
        .navigationTitle(selectedFilter.localizedName + "  ·  \(filteredApps.count)")
        .toolbar {
            if !allIntelApps.isEmpty {
                ToolbarItem {
                    Button {
                        upgradeManager.prepareAndStart(allIntelApps)
                        showUpgradeSheet = true
                    } label: {
                        Label("Upgrade Intel Apps", systemImage: "arrow.up.circle.fill")
                    }
                    .help("Upgrade Intel apps via Homebrew, Cask, or Sparkle")
                    .disabled(upgradeManager.isRunning)
                }
            }

            if !presentSources.isEmpty {
                ToolbarItem {
                    Picker("Source", selection: $selectedSource) {
                        Text("All Sources").tag(ItemSource?.none)
                        ForEach(presentSources, id: \.self) { src in
                            Label(src.localizedName, systemImage: src.icon).tag(ItemSource?.some(src))
                        }
                    }
                    .pickerStyle(.menu).frame(minWidth: 110)
                }
            }

            ToolbarItem {
                Picker("Sort by", selection: $sortByName) {
                    Text("Name").tag(true)
                    Text("Architecture").tag(false)
                }
                .pickerStyle(.segmented)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeSheetView(manager: upgradeManager) { showUpgradeSheet = false }
        }
    }

    @ViewBuilder
    var mainContent: some View {
        if !scanner.hasScanned || (scanner.isScanning && filteredApps.isEmpty) {
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                Text("Scanning, please wait...").foregroundStyle(.secondary)
                Spacer()
            }
        } else if filteredApps.isEmpty {
            ContentUnavailableView(
                "No Matches",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("No apps or packages match the current filter.")
            )
        } else {
            appListView
        }
    }

    var scanProgressBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.65).frame(width: 14, height: 14)
                Text(scanner.statusMessage)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 5).background(.bar)
            Divider()
        }
    }

    var appListView: some View {
        List(filteredApps) { app in
            AppRowView(app: app, upgradeAction: rowUpgradeAction(for: app))
                .contextMenu {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(
                            app.source == .application ? app.bundlePath : (app.executablePath ?? app.bundlePath),
                            inFileViewerRootedAtPath: ""
                        )
                    }
                    Divider()
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(app.executablePath ?? app.bundlePath, forType: .string)
                    }
                    if app.archCategory == .intel {
                        Divider()
                        contextUpgradeItems(for: app)
                    }
                }
        }
        .listStyle(.inset)
    }

    var bottomBar: some View {
        HStack {
            Text(scanner.statusMessage)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            let intelCount = filteredApps.filter { $0.archCategory == .intel }.count
            if intelCount > 0 {
                Text("\(intelCount) Intel")
                    .font(.caption)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12)).foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6).background(.bar)
    }

    // MARK: - Helpers

    /// Returns the upgrade action closure for a row, or nil if no auto-upgrade is available.
    private func rowUpgradeAction(for app: AppInfo) -> (() -> Void)? {
        guard app.archCategory == .intel else { return nil }
        if app.source == .homebrew || app.caskName != nil || app.sparkleURL != nil {
            return {
                upgradeManager.upgradeOne(app)
                showUpgradeSheet = true
            }
        }
        // App Store is handled inline in AppRowView; other apps have no action.
        return nil
    }

    @ViewBuilder
    private func contextUpgradeItems(for app: AppInfo) -> some View {
        if app.source == .homebrew {
            Button("Upgrade via Homebrew") {
                upgradeManager.upgradeOne(app); showUpgradeSheet = true
            }
        } else if app.caskName != nil {
            Button("Upgrade via Homebrew Cask") {
                upgradeManager.upgradeOne(app); showUpgradeSheet = true
            }
        } else if app.sparkleURL != nil {
            Button("Download & Install Latest Version") {
                upgradeManager.upgradeOne(app); showUpgradeSheet = true
            }
        } else if app.isAppStoreApp {
            Button("Check Updates in App Store") {
                NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
            }
        }
    }

    private func count(for option: FilterOption) -> Int {
        let base = selectedSource.map { src in scanner.apps.filter { $0.source == src } } ?? scanner.apps
        guard let category = option.matchingCategory else { return base.count }
        return base.filter { $0.archCategory == category }.count
    }
}

#Preview { ContentView() }

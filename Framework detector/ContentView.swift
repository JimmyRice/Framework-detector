import SwiftUI
import AppKit

// MARK: - Filter Option

enum FilterOption: String, Hashable, CaseIterable, Identifiable {
    case all          = "全部"
    case intel        = "Intel"
    case applesilicon = "Apple Silicon"
    case universal    = "Universal"
    case unknown      = "未知"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:          return "square.grid.2x2"
        case .intel:        return "cpu"
        case .applesilicon: return "cpu"
        case .universal:    return "checkmark.seal.fill"
        case .unknown:      return "questionmark.circle"
        }
    }

    var matchingCategory: ArchCategory? {
        switch self {
        case .all:          return nil
        case .intel:        return .intel
        case .applesilicon: return .applesilicon
        case .universal:    return .universal
        case .unknown:      return .unknown
        }
    }

    var badgeColor: Color {
        matchingCategory?.color ?? .primary
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var scanner = AppScanner()
    @State private var selectedFilter: FilterOption = .intel
    @State private var selectedSource: ItemSource?  = nil   // nil = all sources
    @State private var searchText = ""
    @State private var includeSystemApps = false
    @State private var sortByName = true

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

    // Sources that actually have results (used to build the source picker)
    private var presentSources: [ItemSource] {
        ItemSource.allCases.filter { src in
            scanner.apps.contains { $0.source == src }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索名称")
        .task {
            // Auto-scan once on first launch
            if !scanner.hasScanned {
                scanner.startScan(includeSystem: includeSystemApps)
            }
        }
    }

    // MARK: - Sidebar

    var sidebarView: some View {
        VStack(spacing: 0) {
            List(selection: $selectedFilter) {
                Section("按架构筛选") {
                    ForEach(FilterOption.allCases) { option in
                        HStack {
                            Label(option.rawValue, systemImage: option.systemImage)
                                .foregroundStyle(option.badgeColor)
                            Spacer()
                            Text("\(count(for: option))")
                                .font(.caption)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .tag(option)
                    }
                }

                Section("扫描选项") {
                    Toggle("包含系统应用 (/System)", isOn: $includeSystemApps)
                        .toggleStyle(.checkbox)
                }
            }

            Divider()
            scanButtonPanel
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .navigationTitle("架构检测器")
    }

    var scanButtonPanel: some View {
        VStack(spacing: 8) {
            if scanner.isScanning {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                    Text(scanner.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
                Button {
                    scanner.cancelScan()
                } label: {
                    Label("停止扫描", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.regular)
            } else {
                Button {
                    scanner.startScan(includeSystem: includeSystemApps)
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(12)
        .background(.windowBackground)
    }

    // MARK: - Detail

    var detailView: some View {
        VStack(spacing: 0) {
            if scanner.isScanning {
                scanProgressBar
            }

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !scanner.apps.isEmpty {
                bottomBar
            }
        }
        .navigationTitle("\(selectedFilter.rawValue)  ·  \(filteredApps.count) 个")
        .toolbar {
            // Source picker — only visible after scan returns package results
            if !presentSources.isEmpty {
                ToolbarItem {
                    Picker("来源", selection: $selectedSource) {
                        Text("全部来源").tag(ItemSource?.none)
                        ForEach(presentSources, id: \.self) { src in
                            Label(src.rawValue, systemImage: src.icon).tag(ItemSource?.some(src))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 110)
                }
            }

            ToolbarItem {
                Picker("排序方式", selection: $sortByName) {
                    Text("按名称").tag(true)
                    Text("按架构").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
        }
    }

    @ViewBuilder
    var mainContent: some View {
        if !scanner.hasScanned || (scanner.isScanning && filteredApps.isEmpty) {
            // Scanning in progress, nothing to show yet
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                Text("正在扫描，请稍候…").foregroundStyle(.secondary)
                Spacer()
            }
        } else if filteredApps.isEmpty {
            ContentUnavailableView(
                "无匹配项目",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("当前筛选条件下没有匹配的应用或软件包")
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.bar)
            Divider()
        }
    }

    var appListView: some View {
        List(filteredApps) { app in
            AppRowView(app: app)
                .contextMenu {
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.selectFile(
                            app.source == .application ? app.bundlePath : (app.executablePath ?? app.bundlePath),
                            inFileViewerRootedAtPath: ""
                        )
                    }
                    Divider()
                    Button("复制路径") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(app.executablePath ?? app.bundlePath, forType: .string)
                    }
                }
        }
        .listStyle(.inset)
    }

    var bottomBar: some View {
        HStack {
            Text(scanner.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            let intelCount = filteredApps.filter { $0.archCategory == .intel }.count
            if intelCount > 0 {
                Text("\(intelCount) 个 Intel")
                    .font(.caption)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func count(for option: FilterOption) -> Int {
        let base = selectedSource.map { src in scanner.apps.filter { $0.source == src } } ?? scanner.apps
        guard let category = option.matchingCategory else { return base.count }
        return base.filter { $0.archCategory == category }.count
    }
}

// MARK: - App Row View

struct AppRowView: View {
    let app: AppInfo

    var displayPath: String {
        switch app.source {
        case .application: return app.bundlePath
        default:           return app.executablePath ?? app.bundlePath
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            itemIcon
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                    .lineLimit(1)
                Text(displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if app.source != .application {
                    SourceBadgeView(source: app.source)
                }
                ArchBadgeView(category: app.archCategory)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    var itemIcon: some View {
        switch app.source {
        case .application:
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                .resizable()
                .interpolation(.high)
        default:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(app.source.color.opacity(0.12))
                Image(systemName: app.source.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(app.source.color)
            }
        }
    }
}

// MARK: - Badge Views

struct ArchBadgeView: View {
    let category: ArchCategory
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.systemImage).font(.caption2)
            Text(category.rawValue).font(.caption).fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.color.opacity(0.12))
        .foregroundStyle(category.color)
        .clipShape(Capsule())
    }
}

struct SourceBadgeView: View {
    let source: ItemSource
    var body: some View {
        Text(source.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(source.color.opacity(0.12))
            .foregroundStyle(source.color)
            .clipShape(Capsule())
    }
}

#Preview {
    ContentView()
}

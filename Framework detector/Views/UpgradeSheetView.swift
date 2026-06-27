import SwiftUI

struct UpgradeSheetView: View {
    @ObservedObject var manager: UpgradeManager
    let onClose: () -> Void

    private var hasAutoUpgrade: Bool { manager.totalCount > 0 }
    private var hasApps: Bool { !manager.appStoreApps.isEmpty || !manager.otherIntelApps.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if hasApps {
                appsListView
                    .frame(maxHeight: hasAutoUpgrade ? 220 : .infinity)
                if hasAutoUpgrade { Divider() }
            }

            if hasAutoUpgrade {
                autoUpgradeView.frame(maxHeight: .infinity)
            }

            Divider()
            footerView
        }
        .frame(width: 620, height: 540)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            if manager.isRunning {
                ProgressView().scaleEffect(0.85).frame(width: 20, height: 20)
            } else {
                Image(systemName: "cpu.fill").foregroundStyle(.orange).font(.title3)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Upgrade Intel Apps").font(.headline)
                let total = manager.appStoreApps.count + manager.otherIntelApps.count + manager.totalCount
                if manager.isRunning {
                    Text("Upgrading \(manager.currentItemName)…  (\(manager.completedCount) / \(manager.totalCount))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(total) Intel \(total == 1 ? "item" : "items") found")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - App Store + Manual sections

    private var appsListView: some View {
        List {
            if !manager.appStoreApps.isEmpty {
                Section {
                    ForEach(manager.appStoreApps) { app in
                        appRow(app, badge: "App Store", badgeIcon: "bag")
                    }
                } header: {
                    HStack {
                        Text("App Store  (\(manager.appStoreApps.count))")
                            .font(.subheadline.bold())
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
                        } label: {
                            Label("Open App Store", systemImage: "arrow.up.app")
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }

            if !manager.otherIntelApps.isEmpty {
                Section {
                    ForEach(manager.otherIntelApps) { app in
                        otherAppRow(app)
                    }
                } header: {
                    Text("Manual Update Required  (\(manager.otherIntelApps.count))")
                        .font(.subheadline.bold())
                }
            }
        }
        .listStyle(.inset)
    }

    private func appRow(_ app: AppInfo, badge: String, badgeIcon: String) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                .resizable().interpolation(.high).frame(width: 28, height: 28)
            Text(app.name).lineLimit(1)
            Spacer()
            Label(badge, systemImage: badgeIcon)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func otherAppRow(_ app: AppInfo) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                .resizable().interpolation(.high).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).lineLimit(1)
                Text(app.bundlePath)
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button {
                NSWorkspace.shared.open(app.homepageURL)
            } label: {
                Label("Website", systemImage: "safari")
            }
            .buttonStyle(.bordered).controlSize(.small)
            .help("Visit official website")
            Button {
                NSWorkspace.shared.selectFile(app.bundlePath, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "folder").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help("Show in Finder")
        }
        .padding(.vertical, 2)
    }

    // MARK: - Auto-upgrade terminal (Homebrew + Cask + Sparkle)

    private var autoUpgradeView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if manager.isRunning {
                    ProgressView().scaleEffect(0.65).frame(width: 14, height: 14)
                    Text("Auto-Upgrade — \(manager.currentItemName)…")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                } else {
                    Image(systemName: manager.completedCount > 0 ? "checkmark.circle.fill" : "terminal")
                        .foregroundStyle(manager.completedCount > 0 ? Color.green : Color.secondary)
                        .font(.caption)
                    Text("Auto-Upgrade  (\(manager.completedCount) / \(manager.totalCount) done)")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(manager.output.isEmpty ? " " : manager.output)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: manager.output) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Spacer()
            if manager.isRunning {
                Button("Cancel", role: .cancel) { manager.cancel() }
            } else {
                Button("Close") { onClose() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

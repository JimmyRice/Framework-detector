import SwiftUI

// MARK: - App Row View
struct AppRowView: View {
    let app: AppInfo
    /// Non-nil for Homebrew formulas, Cask apps, and Sparkle apps.
    /// App Store apps are handled inline (open macappstore://), no callback needed.
    var upgradeAction: (() -> Void)? = nil

    var displayPath: String {
        switch app.source {
        case .application: return app.bundlePath
        default:           return app.executablePath ?? app.bundlePath
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            itemIcon.frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.body).lineLimit(1)
                Text(displayPath)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if app.source != .application { SourceBadgeView(source: app.source) }
                ArchBadgeView(category: app.archCategory)
                if app.archCategory == .intel { upgradeButton }
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var upgradeButton: some View {
        switch app.source {
        case .homebrew:
            if let upgradeAction {
                Button(action: upgradeAction) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 15)).foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help(app.caskName != nil ? "Upgrade via Homebrew Cask" : "Upgrade via Homebrew")
            }

        case .application:
            if let upgradeAction, app.caskName != nil {
                // Homebrew Cask
                Button(action: upgradeAction) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 15)).foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Upgrade \(app.name) via Homebrew Cask")
            } else if let upgradeAction, app.sparkleURL != nil {
                // Sparkle (download & replace)
                Button(action: upgradeAction) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 15)).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Download and install latest version")
            } else if app.isAppStoreApp {
                // App Store
                Button {
                    NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
                } label: {
                    Image(systemName: "arrow.up.app")
                        .font(.system(size: 15)).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Check for updates in App Store")
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    var itemIcon: some View {
        switch app.source {
        case .application:
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                .resizable().interpolation(.high)
        default:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(app.source.color.opacity(0.12))
                Image(systemName: app.source.icon)
                    .font(.system(size: 18)).foregroundStyle(app.source.color)
            }
        }
    }
}

import SwiftUI

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

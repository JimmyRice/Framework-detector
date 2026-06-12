import SwiftUI

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
        Text(source.localizedName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(source.color.opacity(0.12))
            .foregroundStyle(source.color)
            .clipShape(Capsule())
    }
}

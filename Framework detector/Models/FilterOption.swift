import SwiftUI

// MARK: - Filter Option
enum FilterOption: String, Hashable, CaseIterable, Identifiable {
    case all          = "All"
    case intel        = "Intel"
    case applesilicon = "Apple Silicon"
    case universal    = "Universal"
    case unknown      = "Unknown"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: LocalizedStringResource(stringLiteral: rawValue))
    }

    var systemImage: String {
        switch self {
        case .all:          return "square.grid.2x2"
        case .intel:        return "cpu"
        case .applesilicon: return AppDevice.currentSiliconIcon
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

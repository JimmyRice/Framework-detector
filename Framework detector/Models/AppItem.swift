import Foundation
import SwiftUI

// MARK: - Item Source
enum ItemSource: String, Hashable, CaseIterable, Sendable {
    case application = "Applications"
    case homebrew    = "Homebrew"
    case macports    = "MacPorts"

    var localizedName: String {
        String(localized: LocalizedStringResource(stringLiteral: rawValue))
    }

    var icon: String {
        switch self {
        case .application: return "app.fill"
        case .homebrew:    return "shippingbox"
        case .macports:    return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .application: return .accentColor
        case .homebrew:    return Color(hue: 0.07, saturation: 0.8, brightness: 0.78)
        case .macports:    return .purple
        }
    }
}

// MARK: - App Info
struct AppInfo: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let bundlePath: String
    let executablePath: String?
    let architectures: Set<ArchType>
    let isSystemApp: Bool
    let source: ItemSource

    // Set during scan if a Homebrew Cask install is detected for this app.
    var caskName: String? = nil
    // Set during scan if the app's Info.plist exposes a Sparkle feed URL.
    var sparkleURL: URL? = nil

    var archCategory: ArchCategory {
        let hasIntel = architectures.contains(.x86_64) || architectures.contains(.i386)
        let hasARM   = architectures.contains(.arm64)  || architectures.contains(.arm)
        if hasIntel && hasARM { return .universal }
        if hasIntel { return .intel }
        if hasARM   { return .applesilicon }
        return .unknown
    }

    // Detects App Store apps by the presence of a MAS receipt inside the bundle.
    var isAppStoreApp: Bool {
        guard source == .application else { return false }
        return FileManager.default.fileExists(atPath: bundlePath + "/Contents/_MASReceipt/receipt")
    }

    // Factory for .app bundles
    static func create(from bundlePath: String, isSystemApp: Bool = false) -> AppInfo? {
        let url = URL(fileURLWithPath: bundlePath)
        guard url.pathExtension == "app" else { return nil }

        let name     = url.deletingPathExtension().lastPathComponent
        let execPath = Bundle(path: bundlePath)?.executablePath
        let archs: Set<ArchType> = execPath.map { MachOReader.architectures(for: $0) } ?? []

        return AppInfo(
            name: name,
            bundlePath: bundlePath,
            executablePath: execPath,
            architectures: archs,
            isSystemApp: isSystemApp,
            source: .application
        )
    }

    // Factory for package manager entries (Homebrew, MacPorts, …)
    static func makePackage(
        name: String,
        displayPath: String,
        executablePath: String,
        source: ItemSource
    ) -> AppInfo? {
        let archs = MachOReader.architectures(for: executablePath)
        guard !archs.isEmpty else { return nil }
        return AppInfo(
            name: name,
            bundlePath: displayPath,
            executablePath: executablePath,
            architectures: archs,
            isSystemApp: false,
            source: source
        )
    }
}

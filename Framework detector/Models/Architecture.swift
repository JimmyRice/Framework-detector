import Foundation
import SwiftUI

// MARK: - Architecture Type
enum ArchType: String, Hashable, CaseIterable, Sendable {
    case x86_64, arm64, i386, arm, unknown
}

// MARK: - Architecture Category
enum ArchCategory: String, Hashable, CaseIterable, Sendable {
    case intel        = "Intel"
    case applesilicon = "Apple Silicon"
    case universal    = "Universal"
    case unknown      = "Unknown"

    var color: Color {
        switch self {
        case .intel:        return .orange
        case .applesilicon: return .blue
        case .universal:    return .green
        case .unknown:      return .gray
        }
    }

    var systemImage: String {
        switch self {
        case .intel:        return "cpu"
        case .applesilicon: return AppDevice.currentSiliconIcon
        case .universal:    return "checkmark.seal.fill"
        case .unknown:      return "questionmark.circle"
        }
    }
}

// MARK: - Mach-O Reader
struct MachOReader {
    // Magic numbers as interpreted on a little-endian (Apple Silicon) host
    private static let MH_MAGIC: UInt32    = 0xFEEDFACE  // 32-bit LE thin
    private static let MH_CIGAM: UInt32    = 0xCEFAEDFE  // 32-bit BE thin
    private static let MH_MAGIC_64: UInt32 = 0xFEEDFACF  // 64-bit LE thin
    private static let MH_CIGAM_64: UInt32 = 0xCFFAEDFE  // 64-bit BE thin
    // Fat header is always big-endian on disk; reading those bytes as LE gives 0xBEBAFECA
    private static let FAT_CIGAM: UInt32   = 0xBEBAFECA

    // CPU type values (from <mach/machine.h>)
    private static let CPU_TYPE_I386:   Int32 = 7
    private static let CPU_TYPE_X86_64: Int32 = 0x01000007
    private static let CPU_TYPE_ARM:    Int32 = 12
    private static let CPU_TYPE_ARM64:  Int32 = 0x0100000C

    static func architectures(for path: String) -> Set<ArchType> {
        // Read only the header — 256 bytes covers all magic + fat_arch entries we need
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { return [] }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 256)
        guard data.count >= 8 else { return [] }

        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }

        switch magic {
        case MH_MAGIC_64, MH_MAGIC:
            let cpu = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
            return [archType(for: cpu)]

        case MH_CIGAM_64, MH_CIGAM:
            let cpu = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }.byteSwapped
            return [archType(for: cpu)]

        case FAT_CIGAM:
            return parseFat(data: data)

        default:
            return []
        }
    }

    private static func parseFat(data: Data) -> Set<ArchType> {
        guard data.count >= 8 else { return [] }
        let nfat = Int(data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }.byteSwapped)
        guard nfat > 0, nfat <= 16 else { return [] }

        var result = Set<ArchType>()
        for i in 0..<nfat {
            let base = 8 + i * 20
            guard base + 4 <= data.count else { break }
            let cpu = data.withUnsafeBytes { $0.load(fromByteOffset: base, as: Int32.self) }.byteSwapped
            result.insert(archType(for: cpu))
        }
        return result
    }

    private static func archType(for cpu: Int32) -> ArchType {
        switch cpu {
        case CPU_TYPE_X86_64: return .x86_64
        case CPU_TYPE_ARM64:  return .arm64
        case CPU_TYPE_I386:   return .i386
        case CPU_TYPE_ARM:    return .arm
        default:              return .unknown
        }
    }
}

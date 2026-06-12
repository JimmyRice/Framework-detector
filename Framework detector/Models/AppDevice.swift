import Foundation

// MARK: - Device Hardware Info
struct AppDevice {
    static let currentSiliconIcon: String = {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelStr = String(cString: model)
        
        if modelStr.contains("Book") { return "laptopcomputer" }
        if modelStr.contains("mini") { return "macmini" }
        if modelStr.contains("Studio") { return "macstudio" }
        if modelStr.contains("iMac") { return "desktopcomputer" }
        if modelStr.contains("Pro") { return "macpro.gen3.fill" }
        
        // If it's a generic new identifier (like Mac14,2), fallback to apple logo
        return "applelogo"
    }()
}

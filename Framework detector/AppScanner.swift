import Foundation
import Combine

@MainActor
final class AppScanner: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var isScanning = false
    @Published var statusMessage = ""
    @Published var hasScanned = false
    @Published var needsPermission = false

    private var scanTask: Task<Void, Never>?

    func startScan(includeSystem: Bool) {
        scanTask?.cancel()
        apps = []
        isScanning = true
        hasScanned = true
        needsPermission = false
        statusMessage = String(localized: "Preparing to scan...")

        scanTask = Task {
            var result: [AppInfo] = []

            // ── 1. App bundles ──────────────────────────────────────────────
            var appDirs: [(path: String, isSystem: Bool)] = [
                ("/Applications", false),
                (FileManager.default.homeDirectoryForCurrentUser.path + "/Applications", false),
            ]
            if includeSystem { appDirs.append(("/System/Applications", true)) }

            for dir in appDirs {
                guard !Task.isCancelled else { break }
                self.statusMessage = String(localized: "Scanning \(dir.path)...")
                let p = dir.path; let s = dir.isSystem
                let found = await Task.detached(priority: .userInitiated) {
                    AppScanner.scanApps(in: p, isSystem: s)
                }.value
                result.append(contentsOf: found)
                self.apps = result
            }

            // ── 1.5. Detect Homebrew Casks and Sparkle feed URLs ────────────
            guard !Task.isCancelled else { self.finish(result); return }
            self.statusMessage = String(localized: "Detecting Cask apps and Sparkle feeds...")
            let caskMap = await Task.detached(priority: .userInitiated) {
                AppScanner.buildCaskMap(prefix: "/usr/local")
                    .merging(AppScanner.buildCaskMap(prefix: "/opt/homebrew")) { _, new in new }
            }.value

            let snapshot = result
            let enriched = await Task.detached(priority: .userInitiated) {
                snapshot.map { app -> AppInfo in
                    guard app.source == .application else { return app }
                    var updated = app
                    if let cask = AppScanner.matchCask(appName: app.name, in: caskMap) {
                        updated.caskName = cask
                    }
                    // Only set Sparkle URL if not App Store and not Cask (prefer Cask upgrade)
                    let hasReceipt = FileManager.default.fileExists(
                        atPath: app.bundlePath + "/Contents/_MASReceipt/receipt")
                    if !hasReceipt, updated.caskName == nil {
                        updated.sparkleURL = AppScanner.extractSparkleURL(for: app.bundlePath)
                    }
                    return updated
                }
            }.value
            result = enriched
            self.apps = result

            // ── 2. Check package manager permissions ────────────────────────
            guard !Task.isCancelled else { self.finish(result); return }
            let permDenied = await Task.detached(priority: .userInitiated) {
                AppScanner.checkPackageManagerAccess()
            }.value
            if permDenied { self.needsPermission = true }

            // ── 3. Homebrew ─────────────────────────────────────────────────
            guard !Task.isCancelled else { self.finish(result); return }
            self.statusMessage = String(localized: "Scanning Homebrew packages...")
            let brewItems = await Task.detached(priority: .userInitiated) {
                AppScanner.scanHomebrewBin(prefix: "/usr/local") +
                AppScanner.scanHomebrewBin(prefix: "/opt/homebrew")
            }.value
            result.append(contentsOf: brewItems)
            self.apps = result

            // ── 4. MacPorts ─────────────────────────────────────────────────
            guard !Task.isCancelled else { self.finish(result); return }
            self.statusMessage = String(localized: "Scanning MacPorts packages...")
            let macportsItems = await Task.detached(priority: .userInitiated) {
                AppScanner.scanMacPorts()
            }.value
            result.append(contentsOf: macportsItems)
            self.apps = result

            self.finish(result)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
        statusMessage = String(localized: "Scan cancelled")
    }

    private func finish(_ result: [AppInfo]) {
        isScanning = false
        let intel  = result.filter { $0.archCategory == .intel }.count
        let apps   = result.filter { $0.source == .application }.count
        let pkgs   = result.count - apps
        statusMessage = pkgs > 0
            ? String(localized: "\(apps) Apps · \(pkgs) Packages · \(intel) Intel")
            : String(localized: "\(apps) Apps · \(intel) Intel")
    }

    // MARK: - Background workers (nonisolated → safe to call from Task.detached)

    nonisolated static func scanApps(in directory: String, isSystem: Bool) -> [AppInfo] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        return entries
            .filter { $0.hasSuffix(".app") }
            .sorted()
            .compactMap { AppInfo.create(from: directory + "/" + $0, isSystemApp: isSystem) }
    }

    /// Builds a [normalizedAppName: caskName] map by listing the Caskroom directory.
    /// Key is the cask name with hyphens replaced by spaces and lowercased, e.g.
    /// "google-chrome" → key "google chrome".
    nonisolated static func buildCaskMap(prefix: String) -> [String: String] {
        let caskroomPath = prefix + "/Caskroom"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: caskroomPath) else { return [:] }
        var map: [String: String] = [:]
        for entry in entries where !entry.hasPrefix(".") {
            let key = entry.lowercased().replacingOccurrences(of: "-", with: " ")
            map[key] = entry
        }
        return map
    }

    nonisolated static func matchCask(appName: String, in map: [String: String]) -> String? {
        map[appName.lowercased()]
    }

    /// Reads SUFeedURL from the app's Info.plist (Sparkle update feed URL).
    nonisolated static func extractSparkleURL(for bundlePath: String) -> URL? {
        guard let bundle = Bundle(path: bundlePath),
              let urlStr = bundle.infoDictionary?["SUFeedURL"] as? String
        else { return nil }
        return URL(string: urlStr)
    }

    nonisolated static func scanHomebrewBin(prefix: String) -> [AppInfo] {
        let fm = FileManager.default
        let cellarPath = prefix + "/Cellar"
        let binPath    = prefix + "/bin"

        guard fm.fileExists(atPath: cellarPath),
              let entries = try? fm.contentsOfDirectory(atPath: binPath) else { return [] }

        var seenFormulas = Set<String>()
        var results: [AppInfo] = []

        for entry in entries.filter({ !$0.hasPrefix(".") }).sorted() {
            let linkPath = binPath + "/" + entry
            let realPath = URL(fileURLWithPath: linkPath).resolvingSymlinksInPath().path

            let cellarPrefix = cellarPath + "/"
            guard realPath.hasPrefix(cellarPrefix) else { continue }

            let afterCellar  = String(realPath.dropFirst(cellarPrefix.count))
            let formulaName  = String(afterCellar.prefix(while: { $0 != "/" }))
            guard !formulaName.isEmpty, !seenFormulas.contains(formulaName) else { continue }

            if let item = AppInfo.makePackage(
                name: formulaName,
                displayPath: realPath,
                executablePath: realPath,
                source: .homebrew
            ) {
                seenFormulas.insert(formulaName)
                results.append(item)
            }
        }
        return results
    }

    nonisolated static func checkPackageManagerAccess() -> Bool {
        let fm = FileManager.default
        let candidates = ["/opt/homebrew/bin", "/usr/local/Cellar", "/opt/local/bin"]
        return candidates.contains { path in
            fm.fileExists(atPath: path) &&
            (try? fm.contentsOfDirectory(atPath: path)) == nil
        }
    }

    nonisolated static func scanMacPorts() -> [AppInfo] {
        let macportsRoot = "/opt/local"
        let binPath      = macportsRoot + "/bin"
        let fm = FileManager.default

        guard fm.fileExists(atPath: binPath + "/port"),
              let entries = try? fm.contentsOfDirectory(atPath: binPath) else { return [] }

        var seenRealPaths = Set<String>()
        var results: [AppInfo] = []

        for entry in entries.filter({ !$0.hasPrefix(".") }).sorted() {
            let filePath = binPath + "/" + entry
            let realPath = URL(fileURLWithPath: filePath).resolvingSymlinksInPath().path

            guard !seenRealPaths.contains(realPath) else { continue }
            seenRealPaths.insert(realPath)

            if let item = AppInfo.makePackage(
                name: entry,
                displayPath: realPath,
                executablePath: realPath,
                source: .macports
            ) {
                results.append(item)
            }
        }
        return results
    }
}

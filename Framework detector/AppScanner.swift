import Foundation
import Combine

@MainActor
final class AppScanner: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var isScanning = false
    @Published var statusMessage = ""
    @Published var hasScanned = false

    private var scanTask: Task<Void, Never>?

    func startScan(includeSystem: Bool) {
        scanTask?.cancel()
        apps = []
        isScanning = true
        hasScanned = true
        statusMessage = "准备扫描..."

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
                self.statusMessage = "正在扫描 \(dir.path)..."
                let p = dir.path; let s = dir.isSystem
                let found = await Task.detached(priority: .userInitiated) {
                    AppScanner.scanApps(in: p, isSystem: s)
                }.value
                result.append(contentsOf: found)
                self.apps = result
            }

            // ── 2. Homebrew ─────────────────────────────────────────────────
            guard !Task.isCancelled else { self.finish(result); return }
            self.statusMessage = "正在扫描 Homebrew 软件包..."
            let brewItems = await Task.detached(priority: .userInitiated) {
                AppScanner.scanHomebrewCellar(at: "/usr/local/Cellar",    source: .homebrew) +
                AppScanner.scanHomebrewCellar(at: "/opt/homebrew/Cellar", source: .homebrew)
            }.value
            result.append(contentsOf: brewItems)
            self.apps = result

            // ── 3. MacPorts ─────────────────────────────────────────────────
            guard !Task.isCancelled else { self.finish(result); return }
            self.statusMessage = "正在扫描 MacPorts 软件包..."
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
        statusMessage = "扫描已取消"
    }

    private func finish(_ result: [AppInfo]) {
        isScanning = false
        let intel  = result.filter { $0.archCategory == .intel }.count
        let apps   = result.filter { $0.source == .application }.count
        let pkgs   = result.count - apps
        statusMessage = pkgs > 0
            ? "共 \(apps) 个应用 · \(pkgs) 个软件包 · \(intel) 个 Intel"
            : "共 \(apps) 个应用 · \(intel) 个 Intel"
    }

    // MARK: - Background workers (nonisolated → safe to call from Task.detached)

    nonisolated static func scanApps(in directory: String, isSystem: Bool) -> [AppInfo] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        return entries
            .filter { $0.hasSuffix(".app") }
            .sorted()
            .compactMap { AppInfo.create(from: directory + "/" + $0, isSystemApp: isSystem) }
    }

    nonisolated static func scanHomebrewCellar(at cellarPath: String, source: ItemSource) -> [AppInfo] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cellarPath),
              let formulas = try? fm.contentsOfDirectory(atPath: cellarPath) else { return [] }

        return formulas
            .filter { !$0.hasPrefix(".") }
            .sorted()
            .compactMap { formula -> AppInfo? in
                let formulaDir = cellarPath + "/" + formula

                // Pick the most-recently-installed version
                guard let versions = try? fm.contentsOfDirectory(atPath: formulaDir),
                      let version  = versions.filter({ !$0.hasPrefix(".") }).sorted().last else { return nil }

                let versionDir = formulaDir + "/" + version

                // Search bin/ then sbin/ for the first Mach-O binary
                for subdir in ["bin", "sbin"] {
                    let binDir = versionDir + "/" + subdir
                    guard let entries = try? fm.contentsOfDirectory(atPath: binDir) else { continue }
                    let candidates = entries.filter { !$0.hasPrefix(".") }.sorted()
                    for candidate in candidates {
                        let execPath = binDir + "/" + candidate
                        if let item = AppInfo.makePackage(
                            name: formula,
                            displayPath: versionDir,
                            executablePath: execPath,
                            source: source
                        ) { return item }
                    }
                }
                return nil
            }
    }

    nonisolated static func scanMacPorts() -> [AppInfo] {
        let binPath = "/opt/local/bin"
        let fm = FileManager.default
        guard fm.fileExists(atPath: binPath),
              let entries = try? fm.contentsOfDirectory(atPath: binPath) else { return [] }

        return entries
            .filter { !$0.hasPrefix(".") }
            .sorted()
            .compactMap { binary in
                AppInfo.makePackage(
                    name: binary,
                    displayPath: binPath,
                    executablePath: binPath + "/" + binary,
                    source: .macports
                )
            }
    }
}

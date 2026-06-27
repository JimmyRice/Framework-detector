import Foundation
import Combine
import AppKit

@MainActor
final class UpgradeManager: ObservableObject {
    @Published var isRunning = false
    @Published var output = ""
    @Published var completedCount = 0
    @Published var totalCount = 0
    @Published var currentItemName = ""

    /// Apps that need the App Store — shown in the sheet's App Store section.
    @Published var appStoreApps: [AppInfo] = []
    /// Apps with no auto-upgrade method — shown in the "Manual Update" section.
    @Published var otherIntelApps: [AppInfo] = []

    private var upgradeTask: Task<Void, Never>?
    private var currentProcess: Process?

    // MARK: - Public API

    /// Categorises all Intel apps and immediately starts auto-upgrades.
    func prepareAndStart(_ allIntelApps: [AppInfo]) {
        appStoreApps   = allIntelApps.filter { $0.source == .application && $0.isAppStoreApp }
        otherIntelApps = allIntelApps.filter {
            $0.source == .application
            && !$0.isAppStoreApp
            && $0.caskName == nil
            && $0.sparkleURL == nil
        }
        var targets: [AppInfo] = []
        targets += allIntelApps.filter { $0.source == .homebrew }
        targets += allIntelApps.filter { $0.source == .application && ($0.caskName != nil || $0.sparkleURL != nil) }

        if !targets.isEmpty {
            begin(targets)
        } else {
            output = ""
            completedCount = 0
            totalCount = 0
            isRunning = false
        }
    }

    /// Upgrade a single app — works for Homebrew formulas, Cask apps, and Sparkle apps.
    func upgradeOne(_ item: AppInfo) {
        guard item.source == .homebrew || item.caskName != nil || item.sparkleURL != nil else { return }
        appStoreApps = []
        otherIntelApps = []
        begin([item])
    }

    func cancel() {
        upgradeTask?.cancel()
        currentProcess?.terminate()
        isRunning = false
        currentItemName = ""
        output += "\n─── Cancelled ───\n"
    }

    // MARK: - Upgrade queue

    private func begin(_ targets: [AppInfo]) {
        upgradeTask?.cancel()
        currentProcess?.terminate()
        output = ""
        completedCount = 0
        totalCount = targets.count
        isRunning = true

        upgradeTask = Task {
            for item in targets {
                guard !Task.isCancelled else { break }
                currentItemName = item.name
                output += "▶ Upgrading \(item.name)...\n"
                let success = await upgradeItem(item)
                completedCount += 1
                output += success
                    ? "✓ \(item.name) done.\n\n"
                    : "⚠ \(item.name) failed or already up to date.\n\n"
            }
            if !Task.isCancelled {
                isRunning = false
                currentItemName = ""
                output += "─── Finished \(completedCount) / \(totalCount) ───\n"
            }
        }
    }

    private static let armBrewPath   = "/opt/homebrew/bin/brew"
    private static let intelBrewPath = "/usr/local/bin/brew"

    private var armBrewAvailable: Bool {
        FileManager.default.fileExists(atPath: Self.armBrewPath)
    }

    private func upgradeItem(_ item: AppInfo) async -> Bool {
        if item.source == .homebrew {
            return await replaceBrewFormula(item)
        }
        if let cask = item.caskName {
            return await replaceBrewCask(cask)
        }
        if let feedURL = item.sparkleURL {
            return await runSparkleUpgrade(item: item, feedURL: feedURL)
        }
        return false
    }

    private func replaceBrewFormula(_ item: AppInfo) async -> Bool {
        let path = item.executablePath ?? item.bundlePath
        let isIntelPrefix = path.contains("/usr/local/Cellar/")

        if isIntelPrefix && armBrewAvailable {
            output += "  Removing Intel version from /usr/local...\n"
            _ = await runBrewStreaming(["uninstall", "--ignore-dependencies", item.name], bin: Self.intelBrewPath)
            output += "  Installing ARM version via /opt/homebrew...\n"
            return await runBrewStreaming(["install", item.name], bin: Self.armBrewPath)
        }

        if isIntelPrefix {
            output += "  ⚠ ARM Homebrew (/opt/homebrew) not found — upgrade only\n"
            return await runBrewStreaming(["upgrade", item.name], bin: Self.intelBrewPath)
        }

        output += "  Reinstalling via ARM Homebrew...\n"
        return await runBrewStreaming(["reinstall", item.name], bin: Self.armBrewPath)
    }

    private func replaceBrewCask(_ cask: String) async -> Bool {
        let isIntelCask = FileManager.default.fileExists(atPath: "/usr/local/Caskroom/" + cask)

        if isIntelCask && armBrewAvailable {
            output += "  Removing Intel cask from /usr/local...\n"
            _ = await runBrewStreaming(["uninstall", "--ignore-dependencies", "--cask", cask], bin: Self.intelBrewPath)
            output += "  Installing ARM cask via /opt/homebrew...\n"
            return await runBrewStreaming(["install", "--cask", cask], bin: Self.armBrewPath)
        }

        if isIntelCask {
            output += "  ⚠ ARM Homebrew (/opt/homebrew) not found — upgrade only\n"
            return await runBrewStreaming(["upgrade", "--cask", cask], bin: Self.intelBrewPath)
        }

        output += "  Reinstalling cask via ARM Homebrew...\n"
        return await runBrewStreaming(["reinstall", "--cask", cask], bin: Self.armBrewPath)
    }

    // MARK: - Homebrew (streaming runner)

    private func runBrewStreaming(_ args: [String], bin: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: bin)
            process.arguments = args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                self?.appendText(text)
            }

            process.terminationHandler = { [weak self] p in
                pipe.fileHandleForReading.readabilityHandler = nil
                let tail = pipe.fileHandleForReading.readDataToEndOfFile()
                if !tail.isEmpty, let text = String(data: tail, encoding: .utf8) {
                    self?.appendText(text)
                }
                continuation.resume(returning: p.terminationStatus == 0)
            }

            self.currentProcess = process
            do { try process.run() } catch {
                self.output += "  Error: \(error.localizedDescription)\n"
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Sparkle

    private func runSparkleUpgrade(item: AppInfo, feedURL: URL) async -> Bool {
        output += "  Fetching update feed...\n"
        guard let release = await fetchLatestRelease(from: feedURL) else {
            output += "  Could not read update feed\n"; return false
        }
        output += "  Latest: v\(release.version) — \(release.downloadURL.lastPathComponent)\n"
        output += "  Downloading...\n"

        guard let localURL = await downloadFile(from: release.downloadURL) else {
            output += "  Download failed\n"; return false
        }
        defer { try? FileManager.default.removeItem(at: localURL) }

        switch localURL.pathExtension.lowercased() {
        case "dmg": return await installDMG(localURL)
        case "zip": return await installZIP(localURL)
        default:
            output += "  Unsupported file type (.\(localURL.pathExtension)) — opening in Finder\n"
            NSWorkspace.shared.open(localURL)
            return false
        }
    }

    private func fetchLatestRelease(from url: URL) async -> SparkleRelease? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        let delegate = SparkleXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.releases.first
    }

    private func downloadFile(from url: URL) async -> URL? {
        guard let (tempURL, _) = try? await URLSession.shared.download(from: url) else { return nil }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
        try? FileManager.default.moveItem(at: tempURL, to: dest)
        return FileManager.default.fileExists(atPath: dest.path) ? dest : nil
    }

    private func installDMG(_ dmgURL: URL) async -> Bool {
        output += "  Mounting disk image...\n"
        let (ok, plistOut) = await runQuiet("/usr/bin/hdiutil",
            args: ["attach", "-nobrowse", "-noautoopen", "-plist", dmgURL.path])
        guard ok, let mountPoint = parseDMGMountPoint(from: plistOut) else {
            output += "  Could not mount disk image\n"; return false
        }
        let result = await installAppFromDirectory(mountPoint)
        // Detach in background (don't block on completion)
        let mp = mountPoint
        Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            p.arguments = ["detach", mp, "-quiet", "-force"]
            try? p.run()
            p.waitUntilExit()
        }
        return result
    }

    private func installZIP(_ zipURL: URL) async -> Bool {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        output += "  Extracting archive...\n"
        let (ok, _) = await runQuiet("/usr/bin/unzip", args: ["-q", zipURL.path, "-d", tempDir.path])
        guard ok else {
            try? FileManager.default.removeItem(at: tempDir)
            output += "  Extraction failed\n"; return false
        }
        let result = await installAppFromDirectory(tempDir.path)
        try? FileManager.default.removeItem(at: tempDir)
        return result
    }

    private func installAppFromDirectory(_ directory: String) async -> Bool {
        guard let appPath = findApp(in: directory) else {
            output += "  No .app bundle found\n"; return false
        }
        let appName = URL(fileURLWithPath: appPath).lastPathComponent
        let destPath = "/Applications/" + appName
        output += "  Installing \(appName) → \(destPath)...\n"
        let (ok, errOut) = await runQuiet("/usr/bin/ditto", args: [appPath, destPath])
        if ok  { output += "  ✓ Installed\n" }
        else   { output += "  Copy failed: \(errOut.trimmingCharacters(in: .whitespacesAndNewlines))\n" }
        return ok
    }

    // MARK: - Process helpers

    nonisolated private func appendText(_ text: String) {
        Task { @MainActor [weak self] in self?.output += text }
    }

    /// Runs a short-lived process, returns (success, combined stdout+stderr).
    /// Does NOT stream to self.output — for internal steps like hdiutil/ditto/unzip.
    private func runQuiet(_ exe: String, args: [String]) async -> (Bool, String) {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: exe)
            process.arguments = args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { p in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (p.terminationStatus == 0, text))
            }

            self.currentProcess = process
            do { try process.run() } catch {
                continuation.resume(returning: (false, error.localizedDescription))
            }
        }
    }

    // MARK: - Parsing helpers

    private func parseDMGMountPoint(from plistString: String) -> String? {
        guard let data = plistString.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]]
        else { return nil }
        return entities.compactMap { $0["mount-point"] as? String }.first
    }

    private func findApp(in directory: String) -> String? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { return nil }
        // Root level
        if let app = entries.first(where: { $0.hasSuffix(".app") && !$0.hasPrefix(".") }) {
            return directory + "/" + app
        }
        // One level deep (e.g. some DMGs have a subfolder)
        for entry in entries where !entry.hasPrefix(".") {
            let sub = directory + "/" + entry
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: sub, isDirectory: &isDir), isDir.boolValue else { continue }
            if let app = (try? fm.contentsOfDirectory(atPath: sub))?
                .first(where: { $0.hasSuffix(".app") && !$0.hasPrefix(".") }) {
                return sub + "/" + app
            }
        }
        return nil
    }
}

// MARK: - Sparkle feed parser

private struct SparkleRelease {
    let version: String
    let downloadURL: URL
}

private final class SparkleXMLParser: NSObject, XMLParserDelegate {
    var releases: [SparkleRelease] = []
    private var pendingURL: URL?
    private var pendingVersion: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        guard elementName == "enclosure",
              let urlStr = attributes["url"],
              let url = URL(string: urlStr)
        else { return }
        pendingURL     = url
        pendingVersion = attributes["sparkle:version"]
            ?? attributes["sparkle:shortVersionString"]
            ?? attributes["version"]
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "item",
              let url = pendingURL,
              let version = pendingVersion
        else { return }
        releases.append(SparkleRelease(version: version, downloadURL: url))
        pendingURL = nil
        pendingVersion = nil
    }
}

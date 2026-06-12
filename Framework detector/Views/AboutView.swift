import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

struct AboutView: View {
    #if canImport(Sparkle)
    let updaterController: SPUStandardUpdaterController
    #endif
    
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 120, height: 120)
                .shadow(radius: 5)
            
            VStack(spacing: 4) {
                Text("Framework Detector")
                    .font(.system(size: 24, weight: .bold))
                
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("A powerful macOS app architecture detection tool.\nQuickly identify Intel, Apple Silicon, and Universal apps.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 16) {
                Button("Check for Updates") {
                    #if canImport(Sparkle)
                    updaterController.checkForUpdates(nil)
                    #else
                    // Do nothing
                    #endif
                }
                .buttonStyle(.borderedProminent)
                
                Button("Project Homepage") {
                    if let url = URL(string: "https://github.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding(.top, 8)
            
            Text("Copyright © 2026. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 10)
        }
        .padding(40)
        .frame(width: 400)
        .fixedSize()
    }
}

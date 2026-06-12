import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    #if canImport(Sparkle)
    let updaterController: SPUStandardUpdaterController
    #endif
    
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Framework Detector") {
                openWindow(id: "about")
            }
        }
        
        CommandGroup(after: .appInfo) {
            Button("Check for Updates...") {
                #if canImport(Sparkle)
                updaterController.checkForUpdates(nil)
                #else
                // Fallback action if Sparkle is not yet installed
                print("Sparkle is not yet installed.")
                #endif
            }
        }
    }
}

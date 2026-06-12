import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

@main
struct Framework_detectorApp: App {
    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    #else
    init() {}
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 960, height: 620)
        .commands {
            #if canImport(Sparkle)
            AppCommands(updaterController: updaterController)
            #else
            AppCommands()
            #endif
        }
        
        Window("About Framework Detector", id: "about") {
            #if canImport(Sparkle)
            AboutView(updaterController: updaterController)
            #else
            AboutView()
            #endif
        }
        .windowResizability(.contentSize)
    }
}

import AppKit
import SwiftUI

@main
struct RyddApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(model)
        } label: {
            let n = model.pendingCount
            Image(nsImage: MenuBarIcon.image(hasFiles: n > 0))
            if n > 0 { Text("\(n)") }
        }
        .menuBarExtraStyle(.menu)

        Window(Text(verbatim: "Rydd"), id: ReviewView.windowID) {
            ReviewView()
                .environmentObject(model)
                .frame(minWidth: 560, minHeight: 360)
        }
        .defaultSize(width: 720, height: 520)
        .defaultLaunchBehavior(Self.launchArg("--open-review") ? .presented : .suppressed)

        Window(Text(verbatim: "Rydd"), id: WelcomeView.windowID) {
            WelcomeView().environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(AppModel.needsOnboarding ? .presented : .suppressed)

        Settings {
            SettingsView().environmentObject(model)
        }
    }

    static func launchArg(_ flag: String) -> Bool { CommandLine.arguments.contains(flag) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon (also set via LSUIElement in the bundle's Info.plist).
        NSApp.setActivationPolicy(.accessory)
    }
}

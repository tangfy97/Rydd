import AppKit
import SwiftUI

/// The menu bar menu — a plain macOS menu, like any other app's.
struct MenuContent: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("About Rydd") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(options: [
                .credits: NSAttributedString(string: String(localized: "Free. Works offline. Nothing leaves your Mac."),
                                             attributes: [.font: NSFont.systemFont(ofSize: 11),
                                                          .foregroundColor: NSColor.secondaryLabelColor]),
            ])
        }
        #if !APPSTORE
        Button("Check for Updates…") { NSWorkspace.shared.open(Links.newVersion) }
        #endif
        Divider()
        if model.onboarded {
            Button(model.pendingCount > 0 ? "Review ^[\(model.pendingCount) File](inflect: true)…" : "Review…") {
                show(ReviewView.windowID)
            }
            if model.lastBatch != nil {
                Button("Undo Last Tidy") { model.undo() }
            }
            Divider()
            if model.isBusy {
                Text("Scanning…")
            } else {
                Button("Rescan") { model.rescan() }
            }
        } else {
            Button("Set Up Rydd…") { show(WelcomeView.windowID) }
        }
        Divider()
        Button("Settings…") {
            openSettings()
            NSApp.activate()
        }
        .keyboardShortcut(",")
        .disabled(!model.onboarded)
        Button("Rydd Help") { NSWorkspace.shared.open(Links.support) }
        Divider()
        Button("Quit Rydd") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }
}

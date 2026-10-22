import AppKit
import SwiftUI

/// First launch, in the style of a macOS setup assistant. Nothing is read before "Start".
struct WelcomeView: View {
    static let windowID = "welcome"
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var step = 0
    @State private var candidates: [URL] = []
    @State private var chosen: Set<URL> = []
    @State private var useAI = true

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcome
                case 1: folders
                default: menuBar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                if step > 0 { Button("Back") { step -= 1 } }
                primary.keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(20)
        }
        .frame(width: 520, height: 440)
        .onAppear {
            candidates = model.suggestedSources
            useAI = model.llmUnavailable == nil
            // Development aid: `--welcome-step N` opens on step N (for screenshots).
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "--welcome-step"), i + 1 < args.count, let n = Int(args[i + 1]) {
                step = n
                if n > 0 { chosen = Set(candidates.prefix(1)) }
            }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Welcome to Rydd").font(.title.bold())
            Text("Rydd keeps the folders you choose tidy. Everything happens on your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)
        }
    }

    private var folders: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Folders").font(.title2.bold())
            Text("Rydd only looks at the folders you choose.").foregroundStyle(.secondary)
            List(candidates, id: \.self) { url in
                Toggle(isOn: Binding(get: { chosen.contains(url) },
                                     set: { if $0 { chosen.insert(url) } else { chosen.remove(url) } })) {
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(verbatim: FileManager.default.displayName(atPath: url.path))
                    }
                }
                .toggleStyle(.checkbox)
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: 150)
            Button("Add Folder…") {
                for url in model.pickFolders() {
                    if !candidates.contains(url) { candidates.append(url) }
                    chosen.insert(url)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 36)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var menuBar: some View {
        VStack(spacing: 12) {
            Image(nsImage: MenuBarIcon.image(hasFiles: true))
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text("Rydd Is in the Menu Bar").font(.title.bold())
            Text("Click the drawer in the menu bar to review and tidy your files.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)
            if model.llmUnavailable == nil {
                HStack(spacing: 6) {
                    Toggle("Sort with Apple Intelligence", isOn: $useAI)
                        .toggleStyle(.checkbox)
                    PrivacyInfo(topic: .appleIntelligence)
                }
                .padding(.top, 12)
            }
        }
    }

    @ViewBuilder private var primary: some View {
        switch step {
        case 0:
            Button("Continue") { step = 1 }
        case 1:
            Button("Continue") { step = 2 }.disabled(chosen.isEmpty)
        default:
            Button("Start") {
                model.finishOnboarding(sources: candidates.filter(chosen.contains), useLLM: useAI)
                openWindow(id: ReviewView.windowID)
                dismissWindow(id: Self.windowID)
            }
        }
    }
}

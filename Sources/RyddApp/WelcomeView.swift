import AppKit
import SwiftUI

/// First launch, in the style of a macOS setup assistant. Nothing is read before "Start".
struct WelcomeView: View {
    static let windowID = "welcome"
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var step = 0
    @State private var accessGranted = false
    @State private var candidates: [URL] = []
    @State private var chosen: Set<URL> = []
    @State private var useAI = true

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch steps[step] {
                case .welcome: welcome
                case .folders: folders
                case .access: access
                case .menuBar: menuBar
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
            accessGranted = model.access.hasHome
            // Development aid: `--welcome-step N` opens on step N (for screenshots).
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "--welcome-step"), i + 1 < args.count, let n = Int(args[i + 1]) {
                step = min(n, steps.count - 1)
                if n > 0 { chosen = Set(candidates.prefix(1)) }
            }
        }
    }

    // MARK: Steps

    private enum Step { case welcome, folders, access, menuBar }

    /// The App Sandbox build asks for folder access; the development build doesn't need to.
    private var steps: [Step] {
        FolderAccess.isSandboxed ? [.welcome, .folders, .access, .menuBar] : [.welcome, .folders, .menuBar]
    }

    private var access: some View {
        VStack(spacing: 12) {
            Image(systemName: accessGranted ? "lock.open" : "lock")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text("Allow Access").font(.title.bold())
            Text("macOS asks you to confirm which folders Rydd may use. Choose your home folder so Rydd can tidy the folders you picked and file things into your folders.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
            if accessGranted {
                Label("Access Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(.top, 8)
            } else {
                Button("Allow Access…") { accessGranted = model.access.requestHome() }
                    .padding(.top, 8)
            }
        }
    }

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
        switch steps[step] {
        case .welcome:
            Button("Continue") { step += 1 }
        case .folders:
            Button("Continue") { step += 1 }.disabled(chosen.isEmpty)
        case .access:
            Button("Continue") { step += 1 }.disabled(!accessGranted)
        case .menuBar:
            Button("Start") {
                model.finishOnboarding(sources: candidates.filter(chosen.contains), useLLM: useAI)
                openWindow(id: ReviewView.windowID)
                dismissWindow(id: Self.windowID)
            }
        }
    }
}

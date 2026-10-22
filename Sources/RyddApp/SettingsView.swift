import AppKit
import ServiceManagement
import SwiftUI

/// Standard macOS settings: General and Folders tabs, grouped rows with System Settings–style icons.
struct SettingsView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(0)
            FolderSettings()
                .tabItem { Label("Folders", systemImage: "folder") }
                .tag(1)
        }
        .frame(width: 480)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $openAtLogin) { SettingLabel("Open at Login", symbol: "power", color: .gray) }
                    .onChange(of: openAtLogin) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }
            }
            Section {
                Picker(selection: $model.minAgeDays) {
                    Text("Right Away").tag(0.0)
                    Text("1 Day").tag(1.0)
                    Text("3 Days").tag(3.0)
                    Text("1 Week").tag(7.0)
                } label: {
                    SettingLabel("Wait Before Tidying", symbol: "clock", color: .blue)
                }
                Toggle(isOn: $model.useLLM) {
                    HStack(spacing: 6) {
                        SettingLabel("Sort with Apple Intelligence", symbol: "sparkles", color: .purple)
                        PrivacyInfo(topic: .appleIntelligence)
                    }
                }
                .disabled(model.llmUnavailable != nil)
                .help(model.llmUnavailable ?? "")
                Toggle(isOn: $model.allowContent) {
                    HStack(spacing: 6) {
                        SettingLabel("Read File Contents", symbol: "doc.text.magnifyingglass", color: .orange)
                        PrivacyInfo(topic: .fileContents)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FolderSettings: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(model.sources, id: \.self, selection: $selection) { url in
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(verbatim: FileManager.default.displayName(atPath: url.path))
                    Spacer()
                    if url.deletingLastPathComponent() != model.home {
                        Text(verbatim: url.deletingLastPathComponent().path.replacingOccurrences(of: model.home.path, with: "~"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: 180)

            // The classic +/− bar under a list.
            HStack(spacing: 0) {
                Button { model.addSource() } label: { Image(systemName: "plus").frame(width: 24, height: 20) }
                    .help(String(localized: "Add Folder…"))
                Divider().frame(height: 16)
                Button {
                    if let s = selection { model.removeSource(s); selection = nil }
                } label: { Image(systemName: "minus").frame(width: 24, height: 20) }
                    .disabled(selection == nil || model.sources.count == 1)
                    .help(String(localized: "Remove"))
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.top, 4)

            if FolderAccess.isSandboxed {
                Divider().padding(.vertical, 14)
                HStack {
                    Label(model.access.hasHome ? "Rydd can use your home folder." : "Rydd can use only the folders you added.",
                          systemImage: model.access.hasHome ? "lock.open" : "lock")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !model.access.hasHome {
                        Button("Allow Access…") { model.requestHomeAccess() }
                    }
                }
            }
        }
        .padding(20)
    }
}

/// A row label with a white SF Symbol on a coloured rounded square, as in System Settings.
private struct SettingLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    let color: Color

    init(_ title: LocalizedStringKey, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(color.gradient))
        }
    }
}

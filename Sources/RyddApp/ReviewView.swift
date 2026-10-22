import AppKit
#if canImport(RyddCore)
import RyddCore
#endif
import SwiftUI

/// Every suggestion in a standard table: tick, name, where it goes. Nothing moves before "Tidy".
struct ReviewView: View {
    static let windowID = "review"
    @EnvironmentObject private var model: AppModel
    @State private var selection = Set<URL>()

    var body: some View {
        VStack(spacing: 0) {
            if model.rows.isEmpty {
                empty
            } else {
                table
            }
            Divider()
            bottomBar
        }
        .navigationTitle(Text(verbatim: "Rydd"))
        .navigationSubtitle(model.onboarded && !model.rows.isEmpty ? Text("^[\(model.pendingCount) File](inflect: true) to Tidy") : Text(verbatim: ""))
        .alert("Some files couldn't be moved.", isPresented: $model.showFailure) {
            Button("OK", role: .cancel) {}
        }
        .modifier(DevSettingsOpener())
    }

    private var table: some View {
        Table(model.orderedRows, selection: $selection) {
            TableColumn("") { row in
                Toggle("", isOn: Binding(get: { row.included }, set: { _ in model.toggle(row.id) }))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(row.destination == nil)
            }
            .width(18)

            TableColumn("Name") { row in
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: row.id.path))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(verbatim: row.item.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .help(row.item.url.deletingLastPathComponent().path)
            }

            TableColumn("Move To") { row in
                DestinationMenu(model: model, row: row)
            }
            .width(min: 150, ideal: 210)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: URL.self) { ids in
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(Array(ids)) }
            Divider()
            Button("Move to Trash") { ids.forEach { model.setDestination(.trash, for: $0) } }
            Button("Don't Tidy") { ids.forEach { model.setDestination(nil, for: $0) } }
        }
    }

    @ViewBuilder private var empty: some View {
        if model.isBusy {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("Nothing to Tidy", systemImage: "checkmark.circle")
            } description: {
                if model.waiting > 0 { Text("Recent files wait a few days.") }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if model.isBusy {
                ProgressView().controlSize(.small)
                Text("Scanning…").foregroundStyle(.secondary)
            }
            Spacer()
            if model.lastBatch != nil {
                Button("Undo Last Tidy") { model.undo() }
            }
            Button(model.pendingCount > 0 ? "Tidy ^[\(model.pendingCount) File](inflect: true)" : "Tidy") {
                model.applyAll()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.pendingCount == 0)
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Development aid: `--open-settings` opens Settings next to this window (for screenshots).
private struct DevSettingsOpener: ViewModifier {
    @Environment(\.openSettings) private var openSettings
    func body(content: Content) -> some View {
        content.task { if RyddApp.launchArg("--open-settings") { openSettings() } }
    }
}

/// The "Move To" pop-up: the user's folders grouped by top-level folder, Trash, or nothing.
/// The model is passed in rather than read from the environment: table cells that AppKit
/// recycles while the rows change don't always get the window's environment objects.
private struct DestinationMenu: View {
    @ObservedObject var model: AppModel
    let row: Row

    var body: some View {
        Menu {
            let groups = Dictionary(grouping: model.folderChoices) { $0.label.split(separator: "/").first.map(String.init) ?? "" }
            ForEach(groups.keys.sorted(), id: \.self) { top in
                Menu(top as String) {
                    ForEach(groups[top] ?? [], id: \.label) { t in
                        Button(String(t.label.dropFirst(top.count + 1)) as String) {
                            model.setDestination(.folder(t.url), for: row.id)
                        }
                    }
                }
            }
            Button("Other Folder…") { model.chooseFolder(for: row.id) }
            Divider()
            Button("Move to Trash") { model.setDestination(.trash, for: row.id) }
            Button("Don't Tidy") { model.setDestination(nil, for: row.id) }
        } label: {
            if let d = row.destination {
                Label {
                    Text(verbatim: model.name(of: d))
                } icon: {
                    Image(systemName: d == .trash ? "trash" : "folder")
                }
            } else {
                Text("Choose…").foregroundStyle(.secondary)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.visible)
        .help(row.suggestion.reason)
    }
}

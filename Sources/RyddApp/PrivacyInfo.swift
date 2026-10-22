import SwiftUI

/// A small ⓘ next to anything AI- or content-related. It opens a short, factual privacy note.
/// Every sentence here must stay true of the code: no networking, on-device model only,
/// file contents read only when the user turns that on, and never written anywhere.
struct PrivacyInfo: View {
    enum Topic { case appleIntelligence, fileContents }

    let topic: Topic
    @State private var shown: Bool

    init(topic: Topic) {
        self.topic = topic
        // Development aid: `--show-privacy` opens the Apple Intelligence note (for screenshots).
        _shown = State(initialValue: topic == .appleIntelligence && RyddApp.launchArg("--show-privacy"))
    }

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .accessibilityLabel(Text("Privacy"))
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Private by Design", systemImage: "lock.shield")
                    .font(.headline)
                ForEach(lines.indices, id: \.self) { i in
                    Text(lines[i]).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
        }
    }

    private var lines: [LocalizedStringKey] {
        switch topic {
        case .appleIntelligence:
            ["Rydd uses Apple's on-device model. It works offline.",
             "The model only sees file and folder names.",
             "Nothing leaves your Mac. Rydd never connects to the internet."]
        case .fileContents:
            ["Files are read on this Mac only, and only when their names aren't enough.",
             "Nothing is uploaded or stored.",
             "Nothing leaves your Mac. Rydd never connects to the internet."]
        }
    }
}

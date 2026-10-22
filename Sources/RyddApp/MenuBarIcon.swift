import AppKit

/// The menu bar icon: the same drawer as the app icon, drawn as a template image so macOS tints it
/// for light and dark menu bars. With files waiting, the top drawer is pulled out and three files
/// stick out of it; once everything is tidy, the cabinet is closed.
enum MenuBarIcon {
    static func image(hasFiles: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.set()
            if hasFiles {
                // Three files of different heights, all ending at the drawer's top edge.
                for (x, top) in [(3.3, 4.0), (7.4, 2.4), (11.5, 4.8)] {
                    NSBezierPath(roundedRect: NSRect(x: x, y: top, width: 3.2, height: 8.6 - top),
                                 xRadius: 0.8, yRadius: 0.8).fill()
                }
            }
            // Top drawer: pulled forward (wider) when open, flush with the cabinet when closed.
            stroke(NSRect(x: hasFiles ? 1.7 : 3, y: 8.2, width: hasFiles ? 14.6 : 12, height: 3.8))
            handle(y: 10.1)
            stroke(NSRect(x: 3, y: 12.8, width: 12, height: 3.6))
            handle(y: 14.6)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = hasFiles ? String(localized: "Rydd: files to tidy") : "Rydd"
        return image
    }

    private static func stroke(_ rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 1.3, yRadius: 1.3)
        path.lineWidth = 1.3
        path.stroke()
    }

    private static func handle(y: CGFloat) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 7.7, y: y))
        path.line(to: NSPoint(x: 10.3, y: y))
        path.lineWidth = 1.3
        path.lineCapStyle = .round
        path.stroke()
    }
}

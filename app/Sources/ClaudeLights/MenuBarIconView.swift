import SwiftUI
import AppKit

/// What actually sits in the menu bar: the sparkle, colored by aggregated
/// state, plus its label — text next to the icon for every state except
/// `idle` (decided with the user via mockup, 2026-09-09). No project name
/// ever appears here (2026-09-09) — just the state.
///
/// Renders the sparkle to a bitmap via ImageRenderer and marks it
/// `isTemplate = false` explicitly. A raw `SparkShape().fill(color)` placed
/// directly in a MenuBarExtra label rendered invisibly when tested live on
/// 2026-09-09 — NSStatusItem defaults custom label content toward template
/// (monochrome, system-controlled) rendering, which silently drops a
/// Shape's own fill color. Pre-rendering to an explicitly non-template
/// NSImage is the robust way around that.
struct MenuBarIconView: View {
    let status: AggregatedStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: Self.sparkImage(color: status.state.color))
                .frame(width: 16, height: 16)
            if let label = status.label {
                Text(label)
                    .font(.system(size: 13))
            }
        }
    }

    private static var cache: [String: NSImage] = [:]

    private static func sparkImage(color: Color) -> NSImage {
        let key = color.description
        if let cached = cache[key] { return cached }

        let renderer = ImageRenderer(content:
            SparkShape()
                .fill(color)
                .frame(width: 16, height: 16)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 16, height: 16))
        image.isTemplate = false
        cache[key] = image
        return image
    }
}

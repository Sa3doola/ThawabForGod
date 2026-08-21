//
//  InlineNotice.swift
//  ThawabForGod
//

import SwiftUI

/// A short explanation that takes the place of content that could not be shown.
///
/// Shared rather than feature-owned because two features already need exactly this shape — the
/// adhkar list and the tasbih list, both of which fail the same way when the corpus cannot be
/// opened — and a third reaching across into another feature's `Views` folder to borrow it would
/// be worse than either the duplication or this file.
///
/// It says its piece without dressing it as an alert: there is nothing to dismiss and nothing to
/// tap, so it sits in the layout where the content would have been.
///
/// **Two tones, because not every empty screen is a fault.** A corpus that will not open is a
/// warning and looks like one. A search that matched nothing, a bookmarks list nobody has added
/// to yet, a commentary that passes over a verse — those are ordinary outcomes, and putting a
/// warning triangle over them tells the reader something is broken when nothing is.
struct InlineNotice: View {

    /// Whether this notice reports a fault or simply reports.
    enum Tone {
        /// Something failed and the reader cannot fix it — a corpus that will not open.
        case warning
        /// An ordinary, correct outcome that happens to leave the screen empty.
        case informational

        var symbol: String {
            switch self {
            case .warning: "exclamationmark.triangle"
            case .informational: "info.circle"
            }
        }
    }

    let message: String
    var tone: Tone = .warning

    @Environment(\.theme) private var theme

    private var tint: Color {
        switch tone {
        case .warning: theme.warning
        case .informational: theme.textSecondary
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tone.symbol)
                .appFont(.title2)
                .foregroundStyle(tint)

            Text(message)
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 0) {
        InlineNotice(message: "The adhkar could not be loaded.")
        InlineNotice(message: "No saved verses yet.", tone: .informational)
    }
    .padding()
    .themed(ThemeManager(settingsStore: InMemorySettingsStore()))
}

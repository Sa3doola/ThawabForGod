//
//  HighlightMenuItems.swift
//  ThawabForGod
//

import SwiftUI

/// The contents of the panel's Highlight menu: four colours by name with a check on the current
/// one, then Remove. Names rather than swatches, because iOS menus draw item icons in one colour.
struct HighlightMenuItems: View {
    let current: HighlightColor?
    let onPick: (HighlightColor?) -> Void

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        ForEach(HighlightColor.allCases) { color in
            Button {
                onPick(color)
            } label: {
                if current == color {
                    Label { name(of: color) } icon: { Image(systemName: "checkmark") }
                } else {
                    name(of: color)
                }
            }
            .accessibilityIdentifier("quran.panel.highlight.\(color.rawValue)")
        }
        if current != nil {
            Divider()
            Button(role: .destructive) {
                onPick(nil)
            } label: {
                Label {
                    Text(l10n.string(.quranHighlightRemove))
                } icon: {
                    Image(systemName: "xmark.circle")
                }
            }
            .accessibilityIdentifier("quran.panel.highlight.remove")
        }
    }

    private func name(of color: HighlightColor) -> some View {
        Text(l10n.string(color.titleKey))
    }
}

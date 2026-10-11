//
//  PanelActionButtonStyle.swift
//  ThawabForGod
//

import SwiftUI

/// The ayah panel's buttons in the reader's own colours, so they read the same on paper, sepia and
/// dark, and in an inactive Mac window (where `.bordered` turns grey and looks disabled).
///
/// Ported from Mushaf. The per-platform font choice it made with `#if os` is gone: `appFont` sizes
/// each text style per platform already.
struct PanelActionButtonStyle: ButtonStyle {
    /// Bordered: a filled, outlined capsule (Copy, Share). Plain: tinted text only (previous / next
    /// ayah, "Read more").
    var isBordered = true
    /// Smaller text and padding (the "show the whole ayah" button over the faded Arabic).
    var isSmall = false

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, isBordered: isBordered, isSmall: isSmall)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let isBordered: Bool
        let isSmall: Bool

        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.readingPalette) private var palette

        var body: some View {
            configuration.label
                .appFont(isSmall ? .caption : .subheadline, weight: .medium)
                .lineLimit(1)
                .foregroundStyle(isBordered ? palette.text : palette.ornament)
                .padding(.horizontal, isBordered ? (isSmall ? 9 : 12) : 0)
                .padding(.vertical, isBordered ? (isSmall ? 4 : 7) : 4)
                .background {
                    if isBordered {
                        Capsule().fill(palette.text.opacity(configuration.isPressed ? 0.14 : 0.06))
                        Capsule().strokeBorder(palette.text.opacity(0.28), lineWidth: 1)
                    }
                }
                .contentShape(Capsule())
                .opacity(isEnabled ? (configuration.isPressed && !isBordered ? 0.6 : 1) : 0.35)
        }
    }
}

extension ButtonStyle where Self == PanelActionButtonStyle {
    static var panelAction: PanelActionButtonStyle { PanelActionButtonStyle() }
    static var panelPlain: PanelActionButtonStyle { PanelActionButtonStyle(isBordered: false) }
    static var panelSmall: PanelActionButtonStyle { PanelActionButtonStyle(isSmall: true) }
}

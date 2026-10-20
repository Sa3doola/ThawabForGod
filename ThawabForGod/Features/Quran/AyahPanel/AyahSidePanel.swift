//
//  AyahSidePanel.swift
//  ThawabForGod
//

import SwiftUI

/// The ayah panel as a trailing column inside the reader: a hairline divider, then the panel.
///
/// Not an `.inspector` (see `AyahPanelLayout`). On a vertical fold `gutter` is the hinge's width: it
/// pads the leading edge so nothing is drawn under the hinge, and the hinge replaces the divider.
struct AyahSidePanel: View {
    let coordinator: QuranCoordinator
    let panel: AyahPanelViewModel
    let reader: QuranReaderViewModel
    let userData: QuranUserDataStore
    let gutter: CGFloat

    @Environment(\.readingPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            if gutter <= 0 {
                Rectangle().fill(palette.divider).frame(width: 1)
            }
            AyahPanel(coordinator: coordinator, panel: panel, reader: reader, userData: userData, isInspector: true)
        }
        .padding(.leading, gutter)
        .background(palette.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quran.sidePanel")
    }
}

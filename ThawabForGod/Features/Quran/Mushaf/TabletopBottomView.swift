//
//  TabletopBottomView.swift
//  ThawabForGod
//

import SwiftUI

/// The bottom half of a horizontally folded display (tabletop): the ayah panel when an ayah is
/// open, otherwise where the reader is and buttons to turn the page. The page itself is on the top
/// half; nothing is drawn across the hinge.
///
/// Ported from Mushaf's `TabletopBottomView`. It reads the panel flag and the Mushaf page in its own
/// body, so the reader's body reads neither.
struct TabletopBottomView: View {
    let coordinator: QuranCoordinator
    let panel: AyahPanelViewModel
    let reader: QuranReaderViewModel
    let userData: QuranUserDataStore

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.readingPalette) private var palette

    var body: some View {
        Group {
            if coordinator.isPanelBottomPresented, coordinator.panelAyah != nil {
                AyahPanel(coordinator: coordinator, panel: panel, reader: reader, userData: userData, isInspector: true)
                    .overlay(alignment: .topTrailing) { closeButton }
            } else {
                controls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    private var closeButton: some View {
        Button { coordinator.closePanel() } label: {
            Label {
                Text(l10n.string(.quranPanelClose))
            } icon: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .labelStyle(.iconOnly)
            .appFont(.title2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.secondaryText)
        .padding(8)
        .accessibilityIdentifier("quran.tabletop.closePanel")
    }

    private var controls: some View {
        let number = reader.mushaf.page
        let page = reader.corpus?.page(number)
        let surah = page?.firstAyah.flatMap { reader.corpus?.surah($0.surah) }
        return VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(verbatim: surah?.name(in: l10n.language) ?? "")
                    .appFont(.title3, weight: .semibold)
                Text(l10n.string(
                    .quranPageFooter,
                    l10n.string(page?.juz ?? 1, grouped: false),
                    l10n.string(number, grouped: false)
                ))
                .appFont(.subheadline)
                .foregroundStyle(palette.secondaryText)
            }
            // A Mushaf turns right-to-left: the next page is on the left, whatever the app language.
            HStack(spacing: 24) {
                pageButton(.next)
                pageButton(.previous)
            }
            .environment(\.layoutDirection, .leftToRight)
            Text(l10n.string(.quranTabletopHint))
                .appFont(.footnote)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(palette.text)
        .padding()
    }

    private func pageButton(_ turn: MushafPageTurn) -> some View {
        let isNext = turn == .next
        return Button {
            reader.mushaf.turn(turn)
        } label: {
            Label {
                Text(l10n.string(isNext ? .quranCommandNextPage : .quranCommandPreviousPage))
            } icon: {
                Image(systemName: isNext ? "chevron.left" : "chevron.right")
            }
            .labelStyle(.iconOnly)
            .appFont(.title2)
            .frame(width: 56, height: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!reader.mushaf.canTurn(turn))
        .accessibilityIdentifier(isNext ? "quran.tabletop.nextPage" : "quran.tabletop.previousPage")
    }
}

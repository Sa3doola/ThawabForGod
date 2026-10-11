//
//  TafsirReaderView.swift
//  ThawabForGod
//

import SwiftUI

/// "Read more": the whole entry, larger and selectable. A sheet over the panel. Ported from Mushaf.
struct TafsirReaderView: View {
    let loaded: AyahPanelTafsir
    let reference: String

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.readingPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var latinSize: CGFloat = 19
    @ScaledMetric(relativeTo: .body) private var arabicSize: CGFloat = 20

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heading
                    TafsirTextView(
                        document: loaded.document, direction: loaded.pack.direction,
                        fontSize: loaded.pack.direction.isRightToLeft ? arabicSize : latinSize,
                        textColor: palette.text, headingColor: palette.ornament
                    )
                    .textSelection(.enabled)
                    TafsirSection.attribution(loaded.pack, l10n: l10n, palette: palette)
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background)
            .navigationTitle(Text(verbatim: loaded.pack.name(in: l10n.language)))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.string(.doneAction)) { dismiss() }
                        .accessibilityIdentifier("quran.tafsirReader.done")
                }
            }
        }
        .presentationDetents([.large])
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: reference)
                .appFont(.headline)
            if loaded.entry.isGroup {
                Text(verbatim: TafsirSection.groupText(loaded.entry, l10n: l10n, isRightToLeft: layoutDirection == .rightToLeft))
                    .appFont(.subheadline)
            }
        }
        .foregroundStyle(palette.secondaryText)
    }
}

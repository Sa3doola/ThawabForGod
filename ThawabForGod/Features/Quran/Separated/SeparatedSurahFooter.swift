//
//  SeparatedSurahFooter.swift
//  ThawabForGod
//

import SwiftUI

/// The end of a surah in separated mode: one button to the next. Laid out in the interface's
/// direction by its caller, so the chevron points the way the app reads.
struct SeparatedSurahFooter: View {
    let next: Surah
    let onTap: () -> Void

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        let name = next.name(in: l10n.language)
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(l10n.string(.quranNextSurah))
                Text(verbatim: name)
                Image(systemName: "chevron.forward")
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityHint(Text(l10n.string(.quranOpensSurah, name)))
        .accessibilityIdentifier("quran.separated.nextSurah")
    }
}

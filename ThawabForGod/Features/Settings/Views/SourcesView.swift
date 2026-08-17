//
//  SourcesView.swift
//  ThawabForGod
//

import SwiftUI

/// Where every bundled data set came from, and under what licence.
///
/// The app ships other people's work — an MIT-licensed adhkar collection, a list of the divine
/// names compiled from public sources, two libraries — and this screen is the app saying so rather
/// than a README nobody installing it will read.
///
/// It also carries the two standing warnings from `Resources/Corpus/README.md`: the adhkar text and
/// the English meanings of the divine names have not been checked by a scholar. Printing that next
/// to the source is the honest version of shipping unverified content, and the notes come out of
/// the same list the content does, so a set that gets verified loses its warning by having its
/// `noteKey` removed.
struct SourcesView: View {
    let sources: [AttributionSource]

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        List(sources) { source in
            SourceRow(source: source)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.settingsSourcesTitle))
    }
}

/// One source: what it is, who made it, the licence, and any caveat that comes with it.
private struct SourceRow: View {
    let source: AttributionSource

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.string(source.titleKey))
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)

            Text(l10n.string(source.attributionKey))
                .appFont(.subheadline)
                .foregroundStyle(theme.textSecondary)

            Text(l10n.string(source.licenceKey))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)

            if let noteKey = source.noteKey {
                Text(l10n.string(noteKey))
                    .appFont(.footnote)
                    .foregroundStyle(theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let url = source.url {
                Link(destination: url) {
                    Text(Self.displayString(for: url))
                        .appFont(.footnote)
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .padding(.vertical, 6)
        // One element per source rather than five: swiping through this screen should be a list
        // of sources, not a list of fragments.
        .accessibilityElement(children: .combine)
    }

    /// The URL without its scheme, wrapped so the bidirectional algorithm leaves it alone.
    ///
    /// The isolates are the same fix `LocaleTimeFormattingService` applies to a countdown, and for
    /// the same reason: dropped into an Arabic paragraph, a URL's slash-separated parts get
    /// reordered by the surrounding direction. A URL reads left to right in both languages.
    private static func displayString(for url: URL) -> String {
        let trimmed = url.absoluteString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        return "\u{2066}\(trimmed)\u{2069}" // LEFT-TO-RIGHT ISOLATE … POP DIRECTIONAL ISOLATE
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        SourcesView(sources: AttributionSource.all)
    }
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}

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

    /// The source whose licence text is open. A sheet rather than a push: it is a document to
    /// glance at and dismiss, and this screen sits on a typed path that has no route for it.
    @State private var openLicence: AttributionSource?

    var body: some View {
        List(sources) { source in
            SourceRow(source: source) { openLicence = source }
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.settingsSourcesTitle))
        .sheet(item: $openLicence) { source in
            LicenceTextView(source: source)
        }
    }
}

/// One source: what it is, who made it, the licence, and any caveat that comes with it.
private struct SourceRow: View {
    let source: AttributionSource
    let onReadLicence: () -> Void

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

            if source.licenceFile != nil {
                Button(action: onReadLicence) {
                    Text(l10n.string(.sourceReadLicence))
                        .appFont(.footnote, weight: .medium)
                        .foregroundStyle(theme.accent)
                }
                // Plain, so the row is not one big button and the link above stays its own
                // target.
                .buttonStyle(.plain)
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

/// A bundled licence, verbatim.
///
/// Monospaced and left-to-right in both languages: these are legal texts in English with their
/// own line breaks and numbered clauses, and they are shown exactly as the licensor wrote them —
/// the OFL in particular must accompany the font unaltered.
private struct LicenceTextView: View {
    let source: AttributionSource

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var text: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(verbatim: text ?? "")
                    .appFont(.footnote)
                    .monospaced()
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.lg)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .background(theme.background)
            .navigationTitle(l10n.string(source.titleKey))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.string(.doneAction)) { dismiss() }
                }
            }
        }
        .task { text = Self.load(source.licenceFile) }
    }

    /// Read out of the bundle, which is the only place these texts are. A file that is missing
    /// shows an empty page rather than an error: the row still names the licence above it.
    private static func load(_ name: String?) -> String? {
        guard let name, let url = Bundle.main.url(forResource: name, withExtension: "txt") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
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

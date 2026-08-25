//
//  TafsirPanel.swift
//  ThawabForGod
//

import SwiftUI

/// What a commentary says about one verse.
///
/// A panel rather than a push, and rather than text expanded inline under the verse. A push would
/// take the reader off the page they are reading; inline text would reflow the whole span and
/// lose their place in it. A panel leaves the verse exactly where it is.
///
/// **Three presentations, one view.** `ReaderView` puts this in an `.inspector`, which is a
/// trailing column at regular width — a pane beside the text on a Mac, 340 points of it on an
/// iPad — and a sheet at compact, where the thumb that opened it can swipe it away. The reader
/// keeps their place in the verses in every one of them.
///
/// **The thumb is an iOS answer, and the Mac needs its own.** There is no swipe-down on a Mac and
/// an inspector has no close of its own, so this carries a Done button under `#if os(macOS)`
/// which calls back through `close` — the same path the swipe takes on iOS. The iPhone and the
/// iPad keep the chrome-free panel this was designed as.
///
/// It carries **no edition picker**, and that is a scope decision rather than an oversight: there
/// is one edition in the bundle today, and a picker over a single row is a control that cannot be
/// used. The repository, the schema and `GetTafsirUseCase` are all written for many — see
/// `TafsirRepositoring` — so the picker is the first thing the second edition brings with it.
struct TafsirPanel: View {
    let viewModel: TafsirViewModel
    let reference: VerseReference
    let surah: Surah?

    /// Puts the panel away. A closure rather than `\.dismiss`, because an inspector is not a
    /// presentation `dismiss` knows how to close — the state lives on the coordinator, and this
    /// is the one call that reaches it.
    let close: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heading
                    content
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: AppBreakpoint.readingMeasure)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(theme.background)
            .navigationTitle(l10n.string(.tafsirTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #else
            // Writes through `QuranCoordinator.closeTafsir()` — the same path the swipe
            // takes on iOS, and the only way out of an inspector pane.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.string(.doneAction), action: close)
                }
            }
            #endif
        }
        // Re-run when the reader taps a different verse without closing the sheet, which is what
        // makes it move rather than needing to be dismissed first.
        .task(id: reference) { await viewModel.load(reference) }
    }

    /// Which verse this is about — the chapter by name, then the number.
    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(surah?.arabicName ?? "")
                .appFont(.title3)
                .foregroundStyle(theme.textPrimary)
                .environment(\.locale, AppLanguage.arabic.locale)

            HStack(spacing: 4) {
                Text(l10n.string(.tafsirVerseLabel))
                Text(l10n.string(reference.verse, grouped: false))
            }
            .appFont(.caption)
            .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView(l10n.string(.tafsirTitle))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)

        case .note(let loaded):
            commentary(loaded)

        case .silent(let edition):
            // Not an error, and not a blank sheet. See `TafsirViewModel.Phase.silent`.
            VStack(alignment: .leading, spacing: 12) {
                InlineNotice(message: l10n.string(.tafsirSilent), tone: .informational)
                attribution(edition)
            }

        case .unavailable:
            InlineNotice(message: l10n.string(.tafsirUnavailable))
        }
    }

    /// The commentary itself, then whose it is.
    private func commentary(_ note: TafsirNote) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(note.text)
                .appFont(.body)
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Set from the *edition*, not from the interface: everything shippable today is
                // Arabic whatever language the app is in, and an English reader's left-aligned
                // paragraph would hang from the wrong edge. The bidi algorithm orders the
                // characters correctly but has nothing to say about that.
                .environment(\.layoutDirection, note.edition.language.isRightToLeft ? .rightToLeft : .leftToRight)
                .environment(\.locale, note.edition.language.locale)

            attribution(note.edition)
        }
    }

    /// Whose commentary this is, and on what footing it is here.
    ///
    /// Always drawn, never behind a disclosure. A note shown without a name invites the reader to
    /// take a five-century-old scholarly opinion for the app's own voice, which is the one thing
    /// this app must not do.
    private func attribution(_ edition: TafsirEdition) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l10n.language == .arabic ? edition.arabicName : edition.englishName)
                .appFont(.caption, weight: .medium)

            Text(l10n.language == .arabic ? edition.arabicAuthor : edition.englishAuthor)
                .appFont(.caption)

            Text(edition.licence)
                .appFont(.caption)
        }
        .foregroundStyle(theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .overlay(alignment: .top) { Divider().background(theme.separator) }
    }
}

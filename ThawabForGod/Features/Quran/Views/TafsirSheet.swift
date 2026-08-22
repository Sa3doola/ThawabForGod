//
//  TafsirSheet.swift
//  ThawabForGod
//

import SwiftUI

/// What a commentary says about one verse.
///
/// A sheet rather than a push, and rather than text expanded inline under the verse. A push would
/// take the reader off the page they are reading; inline text would reflow the whole span and
/// lose their place in it. A sheet leaves the verse where it is and can be dismissed with the
/// thumb that opened it.
///
/// **The thumb is an iOS answer, and the Mac needed its own.** A Mac sheet has no swipe-down and
/// does not close on Escape, so this panel came up with no way out of it at all — the window was
/// stuck until the app was quit. Hence the Done button below, `#if os(macOS)`: the iPhone and the
/// iPad keep the chrome-free sheet this was designed as, because there the swipe is real.
///
/// It carries **no edition picker**, and that is a scope decision rather than an oversight: there
/// is one edition in the bundle today, and a picker over a single row is a control that cannot be
/// used. The repository, the schema and `GetTafsirUseCase` are all written for many — see
/// `TafsirRepositoring` — so the picker is the first thing the second edition brings with it.
struct TafsirSheet: View {
    let viewModel: TafsirViewModel
    let reference: VerseReference
    let surah: Surah?

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    #if os(macOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heading
                    content
                }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(theme.background)
            .navigationTitle(l10n.string(.tafsirTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #else
            // Writes `nil` back through `ReaderView.openTafsir`, which is what calls
            // `QuranCoordinator.closeTafsir()` — the same path the swipe takes on iOS.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.string(.doneAction)) { dismiss() }
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

//
//  QuranLoadFailureView.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran data could not be read: says so, and offers to try again.
///
/// Drawn in the app's own colours rather than a page's: there is no page to match until the corpus
/// has loaded.
struct QuranLoadFailureView: View {
    let retry: () async -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(l10n.string(.quranUnavailable))
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
        } actions: {
            Button {
                Task { await retry() }
            } label: {
                Text(l10n.string(.quranTryAgain))
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("quran.reader.retry")
        }
        .foregroundStyle(theme.textPrimary)
        .background(theme.background)
    }
}

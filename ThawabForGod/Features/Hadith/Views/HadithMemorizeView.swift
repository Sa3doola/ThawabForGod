//
//  HadithMemorizeView.swift
//  ThawabForGod
//

import SwiftUI

/// One review session: a card at a time, recalled and then graded.
///
/// The loop the memorization plan describes — **recall from memory, then check, then say how it
/// went**. The order matters and the screen enforces it: the grade buttons do not appear until
/// the narration is on screen, because grading before seeing the answer is grading something
/// other than recall.
struct HadithMemorizeView: View {
    let viewModel: HadithMemorizeViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                content
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.hadithMemorizeTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView(l10n.string(.hadithLoading))
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 48)

        case .reviewing:
            if let card = viewModel.current {
                progress
                prompt(card)
                narration(card)
                actions
            }

        case .done(let deckIsEmpty):
            InlineNotice(
                message: l10n.string(deckIsEmpty ? .hadithMemorizeEmpty : .hadithMemorizeDone),
                tone: .informational
            )

        case .unavailable:
            InlineNotice(message: l10n.string(.hadithUnavailable))
        }
    }

    /// `2 of 7`, pinned left-to-right so the two numbers do not swap under an Arabic layout.
    private var progress: some View {
        HStack(spacing: 4) {
            Text(l10n.string(viewModel.answered + 1))
            Text(l10n.string(.hadithSearchOf))
            Text(l10n.string(viewModel.total))
        }
        .appFont(.footnote, weight: .semibold)
        .foregroundStyle(theme.textSecondary)
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What the reader is asked from: the citation, and nothing else until they ask for more.
    private func prompt(_ card: HadithReviewCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.string(.hadithMemorizePrompt))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: 6) {
                Text(l10n.string(.hadithNumberLabel))
                Text(l10n.string(card.hadith.reference.first, grouped: false))
            }
            .appFont(.title3, weight: .semibold)
            .foregroundStyle(theme.accent)
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .appCard()
    }

    /// As much of the narration as the reader has asked to see.
    ///
    /// The block keeps its height between steps rather than growing from nothing, so revealing
    /// does not shift the grade buttons out from under a finger already on its way to them.
    @ViewBuilder
    private func narration(_ card: HadithReviewCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.reveal {
            case .hidden:
                Text(l10n.string(.hadithMemorizeRecall))
                    .appFont(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .opening:
                arabic(opening(of: card.hadith.text))

            case .full:
                arabic(card.hadith.text)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .padding(AppSpacing.lg)
        .appCard()
    }

    /// The first words of a narration, as a prompt to find the place by.
    ///
    /// Words rather than characters, so the step never cuts a word in half — which in Arabic
    /// script means cutting a ligature and producing letters nobody wrote.
    private func opening(of text: String) -> String {
        let words = text.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
        guard words.count > 8 else { return text }
        return words.prefix(8).joined(separator: " ") + " …"
    }

    private func arabic(_ text: String) -> some View {
        Text(text)
            .appFont(.body)
            .foregroundStyle(theme.textPrimary)
            .lineSpacing(10)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, AppLanguage.arabic.locale)
    }

    /// Reveal, and then the four grades.
    ///
    /// Never both: the reader either has not seen the answer yet or has, and offering the grades
    /// beside a "show me" button invites grading a card that is still face down.
    @ViewBuilder
    private var actions: some View {
        if viewModel.canGrade {
            grades
        } else {
            Button {
                viewModel.revealMore()
            } label: {
                Text(l10n.string(.hadithMemorizeReveal))
                    .appFont(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.accent, in: .rect(cornerRadius: AppRadius.md))
                    // White rather than a token: this is text on the accent itself, and the
                    // palette has no "on accent" colour because this is the only place it is
                    // needed. Every accent the app offers is dark enough to carry it.
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    /// The four answers, in the order they get easier — which is also the order of the intervals
    /// they produce, so the row reads as a scale rather than as four unrelated buttons.
    private var grades: some View {
        HStack(spacing: 8) {
            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                Button {
                    Task { await viewModel.answer(grade) }
                } label: {
                    VStack(spacing: AppSpacing.xxs) {
                        Text(l10n.string(label(for: grade)))
                            .appFont(.footnote, weight: .semibold)
                            .foregroundStyle(tint(for: grade))

                        // What the answer costs, under the answer. SM-2's whole bargain is that
                        // an honest "hard" today is cheaper than a forgotten card next month,
                        // and a reader who cannot see the intervals has no way to know that —
                        // which is how "good" becomes the button everyone presses.
                        Text(nextLabel(for: grade))
                            .appFont(.caption)
                            .foregroundStyle(tint(for: grade).opacity(0.75))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(tint(for: grade).opacity(0.15), in: .rect(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// `Tomorrow` for one day, `In 12 days` beyond it — a day out is a word rather than a
    /// number, because "in 1 day" is how nobody says it.
    private func nextLabel(for grade: ReviewGrade) -> String {
        guard let days = viewModel.interval(after: grade) else { return "" }

        return days <= 1
            ? l10n.string(.hadithGradeTomorrow)
            : l10n.string(.hadithGradeInDays, l10n.string(days))
    }

    private func label(for grade: ReviewGrade) -> L10nKey {
        switch grade {
        case .again: .hadithGradeAgain
        case .hard: .hadithGradeHard
        case .good: .hadithGradeGood
        case .easy: .hadithGradeEasy
        }
    }

    /// Colour as a second channel beside the label, never as the only one — the labels say which
    /// is which, and a reader who cannot tell the tints apart loses nothing.
    ///
    /// **Not the accent, and "good" least of all.** These four are the one place in the app where
    /// a semantic colour set carries meaning, so they are drawn from the fixed set — Danger,
    /// Warning, Primary, Success — which does not move when the reader picks a different accent.
    /// `.good` was the accent, which meant that a reader on rose saw "good" in almost the same
    /// colour as "again", and a reader on emerald saw it in almost the same colour as "easy". The
    /// four have to stay four whichever of the accents is selected.
    private func tint(for grade: ReviewGrade) -> Color {
        switch grade {
        case .again: theme.danger
        case .hard: theme.warning
        case .good: theme.primary
        case .easy: theme.success
        }
    }
}

//
//  RepeatCounter.swift
//  ThawabForGod
//

import SwiftUI

/// The control that marks a dhikr said, and counts the ones said more than once.
///
/// **Two shapes, and the corpus is why there are two.** 247 of Hisn al-Muslim's 267 adhkar are
/// said exactly once. The countdown this control used to be — a large numeral, the word
/// "remaining", and "of N" beside it — was designed for the twenty, and on the two hundred and
/// forty-seven it rendered as a giant `1 remaining / of 1`: three pieces of arithmetic about a
/// number that was never going to change. So a dhikr said once gets a plain **Mark as said**, and
/// only a dhikr with a target worth counting gets the counter.
///
/// **It counts down, not up**, in the second shape. A reader saying a phrase a hundred times is
/// not interested in how many they have done — they want to know when to stop, and "33 remaining"
/// answers that in one glance where "67 / 100" asks them to subtract. The tally is still there,
/// as the smaller "of 100" beside it, for anyone who wants the whole shape.
///
/// **The button fills as it is counted, from the bottom up.** It replaced a separate progress bar
/// above the control, and it is better for one specific reason: the reader's eyes are on the words
/// above, and the thing their thumb is already on is the only place a progress cue can be seen
/// without looking away from the dhikr.
///
/// Upward rather than sideways, and that is not a stylistic preference. A horizontal fill has a
/// direction, and a direction has to be right in both languages — `UnitPoint` is the one piece of
/// SwiftUI's geometry that does not mirror, so the edge has to be chosen by hand, and choosing it
/// from either `\.layoutDirection` or the interface language was measured on device to give the
/// wrong one. Vertical has no such question: full is up in Arabic and in English.
///
/// **Ninety-six points tall**, which is more than twice the platform minimum and deliberately so.
/// This is the one control in the app that is tapped a hundred times in a row, often with the
/// phone held loosely. A 44-point target is sized for a tap somebody is *looking* at.
///
/// Values in, closures out — it holds no state and knows nothing about a view model, which is what
/// lets it be previewed at any point in its life.
///
/// Both numbers go through `LocalizationManager`, so an Arabic reader counts in ٣٣ rather than in
/// 33. Interpolating them would quietly produce Latin digits whatever the setting.
struct RepeatCounter: View {
    let counted: Int
    let target: Int
    let onCount: () -> Void
    let onReset: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private var isComplete: Bool { counted >= target }
    private var remaining: Int { max(0, target - counted) }
    private var isSingle: Bool { target <= 1 }

    /// How much of the button is filled. Zero for a single-count dhikr, which has no progress to
    /// show — it is either said or it is not, and the completed state says which.
    private var fraction: Double {
        guard !isSingle, target > 0 else { return 0 }
        return min(1, Double(counted) / Double(target))
    }

    /// The height the design fixes. Named rather than inlined because the reading screen lays out
    /// around it, and the two must not drift apart.
    static let height: CGFloat = 96

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            // Drawn only once there is something to undo, and always in the same place, so the
            // count button never changes width under a thumb that is mid-hundred.
            resetButton
                .opacity(counted > 0 ? 1 : 0)
                .disabled(counted == 0)
                .accessibilityHidden(counted == 0)

            countButton
        }
        .animation(.snappy, value: counted)
    }

    private var countButton: some View {
        Button(action: onCount) {
            label
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // On the accent, so the ink is the app's ground rather than a literal white —
                // which is what keeps it legible when the accent is the dark theme's paler amber.
                .foregroundStyle(theme.background)
                .padding(.horizontal, AppSpacing.lg)
                .frame(maxWidth: .infinity)
                .frame(height: Self.height)
                .background(fill)
                .clipShape(.rect(cornerRadius: AppRadius.lg))
        }
        .buttonStyle(.plain)
        .disabled(isComplete)
        // One element, one label: without this VoiceOver reads the numeral, the rule and the two
        // words as separate things and never says what tapping would do.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(.adhkarRepeatLabel))
        .accessibilityValue(isSingle ? l10n.string(isComplete ? .adhkarMarkedRead : .adhkarMarkRead) : tally)
        .accessibilityHint(isComplete ? l10n.string(.adhkarCompleted) : l10n.string(.adhkarCountHint))
    }

    @ViewBuilder
    private var label: some View {
        if isSingle {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .appFont(.title2, weight: .semibold)

                Text(l10n.string(isComplete ? .adhkarMarkedRead : .adhkarMarkRead))
                    .appFont(.title3, weight: .semibold)
            }
        } else {
            HStack(spacing: AppSpacing.md) {
                if isComplete {
                    Image(systemName: "checkmark")
                        .appFont(.title, weight: .bold)
                }

                Text(l10n.string(remaining, grouped: false))
                    .appFont(.largeTitle, weight: .semibold)
                    .monospacedDigit()
                    // Held still: without this the numeral's width follows its glyphs, so the
                    // words beside it shuffle sideways every time 100 becomes 99. The reader's
                    // eyes are on the dhikr above, and movement down here is the one thing that
                    // pulls them off it.
                    .contentTransition(.numericText(countsDown: true))

                // A hairline rather than a gap: the big numeral and the two small words are one
                // sentence — "thirty-three remaining of a hundred" — and a rule is what says the
                // second half explains the first rather than being another figure.
                Rectangle()
                    .fill(theme.background.opacity(0.34))
                    .frame(width: 1, height: 44)

                VStack(alignment: .leading, spacing: 0) {
                    Text(l10n.string(.adhkarRemaining))
                    Text(l10n.string(.adhkarOfTotal, l10n.string(target, grouped: false)))
                }
                .appFont(.footnote, weight: .semibold)
                .opacity(0.9)
            }
        }
    }

    /// The ground under the label: the accent, with the counted part washed lighter from the
    /// bottom up.
    ///
    /// A `scaleEffect` rather than a measured height, so there is no `GeometryReader` inside a
    /// button that is rebuilt on every one of a hundred taps. `.bottom` is the same point in both
    /// layout directions, which is the whole reason the fill runs this way — see the note above.
    private var fill: some View {
        ZStack {
            isComplete ? theme.success : theme.accent

            if !isSingle, fraction > 0, !isComplete {
                Rectangle()
                    .fill(theme.background.opacity(0.22))
                    .scaleEffect(y: fraction, anchor: .bottom)
            }
        }
    }

    private var resetButton: some View {
        Button(action: onReset) {
            Image(systemName: "arrow.counterclockwise")
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 44, height: 44)
                .appCard(radius: AppRadius.pill)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n.string(.adhkarReset))
    }

    /// `"3 / 7"`, in the reader's digits. VoiceOver's value — it says the whole shape, which the
    /// visible label deliberately does not.
    private var tally: String {
        "\(l10n.string(counted, grouped: false)) / \(l10n.string(target, grouped: false))"
    }
}

#Preview("Said once — the 247") {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 20) {
        RepeatCounter(counted: 0, target: 1, onCount: {}, onReset: {})
        RepeatCounter(counted: 1, target: 1, onCount: {}, onReset: {})
    }
    .padding()
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}

#Preview("Counted — the 20") {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 20) {
        RepeatCounter(counted: 0, target: 3, onCount: {}, onReset: {})
        RepeatCounter(counted: 67, target: 100, onCount: {}, onReset: {})
        RepeatCounter(counted: 100, target: 100, onCount: {}, onReset: {})
    }
    .padding()
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}

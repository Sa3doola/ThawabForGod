//
//  RepeatCounter.swift
//  ThawabForGod
//

import SwiftUI

/// The tap target that counts a dhikr's recitations down to zero.
///
/// **It counts down, not up, and that is the whole of the redesign.** A reader saying a phrase a
/// hundred times is not interested in how many they have done — they want to know when to stop,
/// and "33 remaining" answers that in one glance where "67 / 100" asks them to subtract. The
/// tally is still there, as the smaller "of 100" beside it, for anyone who wants the whole shape.
///
/// **Ninety-six points tall**, which is more than twice the platform minimum and deliberately so.
/// This is the one control in the app that is tapped a hundred times in a row, often with the
/// phone held loosely and the reader's eyes on the words above rather than on their thumb. A
/// 44-point target is sized for a tap somebody is *looking* at.
///
/// Values in, closures out — it holds no state and knows nothing about a view model, which is
/// what lets it be previewed at any point in its life and reused by the tasbih screen later.
///
/// Both numbers go through `LocalizationManager`, so an Arabic reader counts in ٣٣ rather than
/// in 33. Interpolating them would quietly produce Latin digits whatever the setting.
struct RepeatCounter: View {
    let counted: Int
    let target: Int
    let onCount: () -> Void
    let onReset: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private var isComplete: Bool { counted >= target }
    private var remaining: Int { max(0, target - counted) }

    /// The height the design fixes. Named rather than inlined because the hint under the counter
    /// tells the reader the number, and the two must not drift apart.
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
            HStack(spacing: AppSpacing.md) {
                if isComplete {
                    Image(systemName: "checkmark")
                        .appFont(.title, weight: .bold)
                }

                Text(l10n.string(remaining, grouped: false))
                    .appFont(.largeTitle, weight: .semibold)
                    .monospacedDigit()

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
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            // On the accent, so the ink is the app's ground rather than a literal white — which
            // is what keeps it legible when the accent is the dark theme's paler amber.
            .foregroundStyle(theme.background)
            .padding(.horizontal, AppSpacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .background(
                isComplete ? theme.success : theme.accent,
                in: .rect(cornerRadius: AppRadius.lg)
            )
        }
        .buttonStyle(.plain)
        .disabled(isComplete)
        // One element, one label: without this VoiceOver reads the numeral, the rule and the two
        // words as separate things and never says what tapping would do.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(.adhkarRepeatLabel))
        .accessibilityValue(tally)
        .accessibilityHint(isComplete ? l10n.string(.adhkarCompleted) : l10n.string(.adhkarCountHint))
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

#Preview {
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

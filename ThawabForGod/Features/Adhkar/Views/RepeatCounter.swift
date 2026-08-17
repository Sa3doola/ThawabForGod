//
//  RepeatCounter.swift
//  ThawabForGod
//

import SwiftUI

/// The tap target that counts a dhikr's recitations against the number it asks for.
///
/// Values in, closures out — it holds no state and knows nothing about a view model, which is
/// what lets it be previewed at any point in its life and reused by the tasbih screen later.
///
/// Both numbers go through `LocalizationManager`, so an Arabic reader counts in ٣ / ٧ rather
/// than in 3 / 7. Interpolating them would quietly produce Latin digits whatever the setting.
struct RepeatCounter: View {
    let counted: Int
    let target: Int
    let onCount: () -> Void
    let onReset: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private var isComplete: Bool { counted >= target }

    var body: some View {
        HStack(spacing: 12) {
            if counted > 0 {
                resetButton
            }

            countButton
        }
        // The tally reads right-to-left as readily as left-to-right, so it is left to mirror
        // with the rest of the screen rather than pinned.
        .animation(.snappy, value: counted)
    }

    private var countButton: some View {
        Button(action: onCount) {
            HStack(spacing: 8) {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                }

                Text(tally)
                    .appFont(.headline, weight: .semibold)
                    .monospacedDigit()
            }
            .foregroundStyle(isComplete ? theme.success : theme.accent)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                (isComplete ? theme.success : theme.accent).opacity(0.12),
                in: .rect(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .disabled(isComplete)
        // One element, one label: without this VoiceOver reads the tick and the tally as two
        // unrelated things and never says what tapping would do.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(.adhkarRepeatLabel))
        .accessibilityValue(tally)
        .accessibilityHint(isComplete ? l10n.string(.adhkarCompleted) : l10n.string(.adhkarCountHint))
    }

    private var resetButton: some View {
        Button(action: onReset) {
            Image(systemName: "arrow.counterclockwise")
                .foregroundStyle(theme.textSecondary)
                .padding(12)
                .background(theme.surface, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n.string(.adhkarReset))
    }

    /// `"3 / 7"`, in the reader's digits.
    private var tally: String {
        "\(l10n.string(counted, grouped: false)) / \(l10n.string(target, grouped: false))"
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 20) {
        RepeatCounter(counted: 0, target: 3, onCount: {}, onReset: {})
        RepeatCounter(counted: 2, target: 3, onCount: {}, onReset: {})
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

//
//  CounterButton.swift
//  ThawabForGod
//

import SwiftUI

/// The thing you tap. A large disc showing the count inside a ring that fills as the lap does.
///
/// Values in, closures out, like `RepeatCounter` — it holds no state and knows nothing about a
/// view model, so it can be previewed at any point in a lap.
///
/// Big on purpose. This is a control used with a thumb, repeatedly, often without looking at it,
/// so it is sized to be found by feel rather than by aim.
struct CounterButton: View {
    let count: Int
    let target: Int
    let progress: Double
    let onCount: () -> Void
    let onReset: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// Drives the press-in, which a `Button` would have given for free. Tracked by hand for the
    /// reason the control is not a `Button` — see `body`.
    @State private var isPressed = false

    private let diameter: CGFloat = 260

    /// Not a `Button`, deliberately, and this is the one place in the app that departs from
    /// "every tappable thing is a `Button`".
    ///
    /// A `Button` consumes the press for its own recogniser, so a `.onLongPressGesture` attached
    /// alongside it never fires — hold the disc and you get an increment on release, which is the
    /// opposite of what was asked for. Making the long press `simultaneous` instead fires *both*,
    /// resetting and then counting one. So the two gestures are declared together on a plain
    /// view, where SwiftUI resolves them against each other properly.
    ///
    /// What a `Button` would have provided is put back explicitly below: the pressed state, the
    /// button trait, and an activation action so VoiceOver's double-tap still counts.
    var body: some View {
        ZStack {
            ring
            tally
        }
        .frame(width: diameter, height: diameter)
        // Without this the gaps between the ring and the numerals are not part of the control,
        // and a thumb landing there does nothing.
        .contentShape(.circle)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.snappy(duration: 0.15), value: isPressed)
        .onTapGesture(perform: onCount)
        // A long press rather than a reset button beside the count: a control within reach of a
        // thumb tapping a hundred times is a control that eventually gets hit at 98. The gesture
        // is invisible, which is what `TasbihResetTip` is for.
        .onLongPressGesture(minimumDuration: 0.6) {
            onReset()
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(.tasbihCountLabel))
        .accessibilityValue(spokenValue)
        .accessibilityHint(l10n.string(.tasbihCountHint))
        .accessibilityAddTraits(.isButton)
        // The default action, so a VoiceOver double-tap counts as a tap does.
        .accessibilityAction(.default, onCount)
        // And a named one, because VoiceOver cannot perform a long press at all.
        .accessibilityAction(named: Text(l10n.string(.tasbihReset)), onReset)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(theme.surface)

            Circle()
                .strokeBorder(theme.separator, lineWidth: 14)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .padding(7)
                // Trim starts at three o'clock; a progress ring should start at the top.
                .rotationEffect(.degrees(-90))
                // Pinned left-to-right, because `rotationEffect` is mirrored under an RTL layout
                // direction — which turned this -90° into +90° and started the ring at the
                // *bottom* on an Arabic screen. A dial is a geometric figure rather than a line
                // of text: it starts at twelve o'clock and fills clockwise in both languages,
                // the way the face of a watch does.
                .environment(\.layoutDirection, .leftToRight)
                .animation(.snappy, value: progress)
        }
    }

    private var tally: some View {
        VStack(spacing: 4) {
            Text(l10n.string(count, grouped: false))
                .appFont(.largeTitle, weight: .bold)
                // Without this the disc jitters as the glyph widths change between 1 and 8.
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: count)

            Text(l10n.string(target, grouped: false))
                .appFont(.callout)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
        }
    }

    /// `"7 of 33"` — read as a value rather than shown, so VoiceOver says something meaningful
    /// instead of a bare number with no scale.
    private var spokenValue: String {
        "\(l10n.string(count, grouped: false)) / \(l10n.string(target, grouped: false))"
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 32) {
        CounterButton(count: 0, target: 33, progress: 0, onCount: {}, onReset: {})
        CounterButton(count: 21, target: 33, progress: 21 / 33, onCount: {}, onReset: {})
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

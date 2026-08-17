//
//  SettingsRows.swift
//  ThawabForGod
//

import SwiftUI

/// One preference, as a labelled picker.
///
/// Generic over `SettingsChoice`, which is what lets the seven pickers on this screen — accent,
/// appearance, language, digits, clock, method, madhab — be one row rather than seven.
///
/// `.menu` rather than `.segmented`: the calculation method has twelve long names, and a style
/// that only suits the short lists would mean two rows again. It is also the style that reads
/// correctly on iOS and macOS both, and it mirrors for Arabic without any help.
struct SettingsPickerRow<Value: SettingsChoice>: View {
    let titleKey: L10nKey
    @Binding var selection: Value

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Picker(selection: $selection) {
            ForEach(Array(Value.allCases)) { value in
                Text(l10n.string(value.labelKey)).tag(value)
            }
        } label: {
            Text(l10n.string(titleKey))
        }
        .pickerStyle(.menu)
    }
}

/// The accent choice, as the colours themselves.
///
/// A picker listing four colour *names* would be the one control on this screen that asks the
/// reader to imagine the result. Four swatches do not, and they carry no text to translate.
struct AccentSwatchRow: View {
    @Binding var selection: AccentPalette

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.string(.accentLabel))
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            HStack(spacing: 16) {
                ForEach(AccentPalette.allCases) { palette in
                    swatch(palette)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 4)
    }

    private func swatch(_ palette: AccentPalette) -> some View {
        let isSelected = selection == palette

        return Button {
            selection = palette
        } label: {
            Circle()
                .fill(theme.color(of: palette))
                .frame(width: 32, height: 32)
                .overlay {
                    // A ring rather than a size change, so choosing one does not reflow the row.
                    Circle()
                        .strokeBorder(theme.textPrimary, lineWidth: isSelected ? 2 : 0)
                        .padding(-4)
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .appFont(.footnote, weight: .bold)
                            .foregroundStyle(theme.background)
                    }
                }
        }
        // Plain, or the button style would tint every swatch with the current accent and all
        // four would look the same.
        .buttonStyle(.plain)
        // The circle is decoration as far as VoiceOver is concerned; the colour's name is the
        // label, and `.isSelected` is what tells the reader which one is in effect.
        .accessibilityLabel(l10n.string(palette.labelKey))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A read-only line: a label, and a value the settings above it change.
///
/// `LabeledContent` rather than an `HStack` with a `Spacer`, so the pairing follows the platform's
/// own settings idiom and mirrors for Arabic without this file knowing which way round it is.
struct SettingsValueRow: View {
    let titleKey: L10nKey
    let value: String

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        LabeledContent {
            Text(value)
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)
        } label: {
            Text(l10n.string(titleKey))
                .foregroundStyle(theme.textPrimary)
        }
    }
}

/// One preference, as a switch.
struct SettingsToggleRow: View {
    let titleKey: L10nKey
    @Binding var isOn: Bool

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(l10n.string(titleKey))
                .foregroundStyle(theme.textPrimary)
        }
    }
}

/// A row that leaves the app for the system's own settings.
///
/// Distinct from `SettingsDisclosureRow` in the one way that matters to a reader: the symbol.
/// A chevron promises another screen inside this app; `arrow.up.forward.app` says the tap is
/// about to put a different app in front of them, which is the honest thing to promise before
/// it happens.
struct SettingsExternalRow: View {
    let titleKey: L10nKey
    let value: String
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack {
                Text(l10n.string(titleKey))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text(value)
                    .foregroundStyle(theme.textSecondary)
                Image(systemName: "arrow.up.forward.app")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// A row that opens a sub-screen.
///
/// A `Button` rather than a `NavigationLink`, because the push is the coordinator's decision to
/// make — the same reason every other feature here routes through one. `chevron.forward` rather
/// than `chevron.right`: the semantic direction flips for Arabic, the literal one does not.
struct SettingsDisclosureRow: View {
    let titleKey: L10nKey
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack {
                Text(l10n.string(titleKey))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.forward")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
            }
            // So the whole width of the row is the target, not just the text.
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

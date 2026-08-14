//
//  DesignSystemGallery.swift
//  ThawabForGod
//

import SwiftUI

/// Developer screen showing every semantic colour and every step of the type scale.
///
/// It is the app's root for now so the design system can be checked on a real device in
/// light/dark, at accessibility text sizes, and with each accent. A later step restores the
/// real root and this becomes preview-only. Its labels are deliberately not localized.
struct DesignSystemGallery: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.theme) private var theme

    private var accentSelection: Binding<AccentPalette> {
        Binding(
            get: { themeManager.accent },
            set: { themeManager.select(accent: $0) }
        )
    }

    private var appearanceSelection: Binding<AppearanceOverride> {
        Binding(
            get: { themeManager.appearance },
            set: { themeManager.select(appearance: $0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                pickers
                palette
                typeScale
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background)
    }

    private var pickers: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: "Design system")
                .appFont(.largeTitle, weight: .bold)
                .foregroundStyle(theme.textPrimary)

            Picker(selection: accentSelection) {
                ForEach(AccentPalette.allCases) { palette in
                    Text(verbatim: palette.developerLabel).tag(palette)
                }
            } label: {
                Text(verbatim: "Accent")
            }
            .pickerStyle(.segmented)

            Picker(selection: appearanceSelection) {
                ForEach(AppearanceOverride.allCases) { appearance in
                    Text(verbatim: appearance.developerLabel).tag(appearance)
                }
            } label: {
                Text(verbatim: "Appearance")
            }
            .pickerStyle(.segmented)
        }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Palette")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(swatches, id: \.name) { swatch in
                    Swatch(name: swatch.name, color: swatch.color, theme: theme)
                }
            }
        }
    }

    private var swatches: [(name: String, color: Color)] {
        [
            ("primary", theme.primary),
            ("accent", theme.accent),
            ("background", theme.background),
            ("surface", theme.surface),
            ("textPrimary", theme.textPrimary),
            ("textSecondary", theme.textSecondary),
            ("separator", theme.separator),
            ("success", theme.success),
            ("warning", theme.warning),
            ("danger", theme.danger)
        ]
    }

    private var typeScale: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Type scale")

            ForEach(AppTextStyle.allCases, id: \.self) { style in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: style.rawValue)
                        .appFont(style)
                        .foregroundStyle(theme.textPrimary)
                    Text(verbatim: "بسم الله الرحمن الرحيم")
                        .appFont(style)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(verbatim: title)
            .appFont(.title2, weight: .semibold)
            .foregroundStyle(theme.textPrimary)
    }
}

private struct Swatch: View {
    let name: String
    let color: Color
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .frame(height: 56)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(theme.separator)
                }
            Text(verbatim: name)
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

#Preview {
    let themeManager = ThemeManager(settingsStore: InMemorySettingsStore())

    DesignSystemGallery()
        .themed(themeManager)
}

//
//  QuranSettingsForm.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran's settings, as one grouped form. Mushaf's `ReaderSettingsView` without its backup and
/// numerals rows (MAPPING.md), shown both as Settings → Quran and as the reader's sheet; the two
/// differ only in what the two row closures do, and in who supplies the title and the Done button.
///
/// Every control reads from and writes to `QuranReaderSettings` through the view model with a
/// `Binding(get:set:)`, so opening the form writes nothing.
struct QuranSettingsForm: View {
    let viewModel: QuranSettingsViewModel
    let onShowPacks: () -> Void
    let onShowSources: () -> Void

    @Environment(LocalizationManager.self) private var l10n

    private var settings: QuranReaderSettings { viewModel.settings }

    var body: some View {
        Form {
            displaySection
            themeSection
            textSection
            if settings.capabilities.supportsMushafPages {
                mushafSection
            }
            if QuranSettingsPlatform.showsKeepScreenAwake {
                screenSection
            }
            sourcesSection
            resetSection
        }
        // Grouped on the Mac too: the default columns style clipped labels and cut footers short.
        .formStyle(.grouped)
        .accessibilityIdentifier("quran.settings.form")
    }

    // MARK: Sections

    private var displaySection: some View {
        Section {
            if settings.availableDisplayModes.count > 1 {
                Picker(selection: Binding(
                    get: { settings.displayMode },
                    set: { viewModel.setDisplayMode($0) }
                )) {
                    ForEach(settings.availableDisplayModes) { mode in
                        Text(l10n.string(mode.labelKey)).tag(mode)
                    }
                } label: {
                    Text(l10n.string(.quranSettingsDisplayMode))
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("quran.settings.displayMode")
            }
            Button(action: onShowPacks) {
                Label {
                    Text(l10n.string(.quranPacksTitle))
                } icon: {
                    Image(systemName: "text.book.closed")
                }
            }
            .accessibilityIdentifier("quran.settings.packs")
            Toggle(isOn: Binding(
                get: { settings.showsTranslationInSeparated },
                set: { settings.setShowsTranslationInSeparated($0) }
            )) {
                Text(l10n.string(.quranSettingsTranslationUnderAyah))
            }
            .accessibilityIdentifier("quran.settings.translationUnderAyah")
        } header: {
            Text(l10n.string(.quranSettingsDisplayMode))
        } footer: {
            Text(l10n.string(.quranSettingsDisplayFooter))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var themeSection: some View {
        Section {
            Picker(selection: Binding(
                get: { settings.theme },
                set: { settings.select(theme: $0) }
            )) {
                ForEach(ReaderTheme.allCases) { theme in
                    Text(l10n.string(theme.labelKey)).tag(theme)
                }
            } label: {
                Text(l10n.string(.quranSettingsTheme))
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("quran.settings.theme")
            Toggle(isOn: Binding(
                get: { settings.followsSystemAppearance },
                set: { settings.setFollowsSystemAppearance($0) }
            )) {
                Text(l10n.string(.quranSettingsFollowDark))
            }
            .accessibilityIdentifier("quran.settings.followSystem")
        } header: {
            Text(l10n.string(.quranSettingsTheme))
        }
    }

    private var textSection: some View {
        Section {
            Picker(selection: Binding(
                get: { settings.font },
                set: { settings.select(font: $0) }
            )) {
                ForEach(ReaderFont.allCases) { font in
                    Text(l10n.string(font.labelKey)).tag(font)
                }
            } label: {
                Text(l10n.string(.readerFontSection))
            }
            .accessibilityIdentifier("quran.settings.font")
            Slider(
                value: Binding(
                    get: { settings.textSize },
                    set: { settings.setTextSize($0) }
                ),
                in: QuranReaderSettings.textSizeRange,
                step: QuranReaderSettings.textSizeStep
            ) {
                Text(l10n.string(.readerTextSize))
            } minimumValueLabel: {
                Image(systemName: "textformat.size.smaller")
            } maximumValueLabel: {
                Image(systemName: "textformat.size.larger")
            }
            .accessibilityIdentifier("quran.settings.textSize")
        } header: {
            Text(l10n.string(.readerTextSize))
        } footer: {
            Text(l10n.string(.quranSettingsTextFooter))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var mushafSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.showsMarginMarkers },
                set: { settings.setShowsMarginMarkers($0) }
            )) {
                Text(l10n.string(.quranSettingsMarginMarkers))
            }
            .accessibilityIdentifier("quran.settings.marginMarkers")
            if DeviceKind.isPhone {
                Picker(selection: Binding(
                    get: { settings.phoneLandscape },
                    set: { settings.select(phoneLandscape: $0) }
                )) {
                    ForEach(PhoneLandscapeLayout.allCases) { layout in
                        Text(l10n.string(layout.labelKey)).tag(layout)
                    }
                } label: {
                    Text(l10n.string(.quranSettingsLandscape))
                }
                .accessibilityIdentifier("quran.settings.landscape")
                Picker(selection: Binding(
                    get: { settings.flatOpen },
                    set: { settings.select(flatOpen: $0) }
                )) {
                    ForEach(FlatOpenLayout.allCases) { layout in
                        Text(l10n.string(layout.labelKey)).tag(layout)
                    }
                } label: {
                    Text(l10n.string(.quranSettingsOpenFlat))
                }
                .accessibilityIdentifier("quran.settings.openFlat")
            }
        } header: {
            Text(l10n.string(.quranSettingsMushafPages))
        } footer: {
            Text(l10n.string(.quranSettingsMarginMarkersFooter))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var screenSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.keepsScreenAwake },
                set: { settings.setKeepsScreenAwake($0) }
            )) {
                Text(l10n.string(.readerKeepScreenAwake))
            }
            .accessibilityIdentifier("quran.settings.keepAwake")
        } footer: {
            Text(l10n.string(.readerKeepScreenAwakeDetail))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourcesSection: some View {
        Section {
            Button(action: onShowSources) {
                Label {
                    Text(l10n.string(.quranSettingsSources))
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
            .accessibilityIdentifier("quran.settings.sources")
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.reset()
            } label: {
                Text(l10n.string(.readerReset))
            }
            .accessibilityIdentifier("quran.settings.reset")
        }
    }
}

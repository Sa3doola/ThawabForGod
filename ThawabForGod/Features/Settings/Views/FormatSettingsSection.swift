//
//  FormatSettingsSection.swift
//  ThawabForGod
//

import SwiftUI
#if canImport(UIKit)
import UIKit // `openSettingsURLString`; MEMBER_IMPORT_VISIBILITY means SwiftUI does not re-export it
#endif

/// Language, digits and clock — the three choices that are deliberately separate.
///
/// Separate because they answer different questions: an Arabic reader may prefer Latin digits, and
/// a reader in either language may want 24-hour times. A single `Locale` cannot express those
/// combinations, which is the reason `LocalizationManager` exists at all.
///
/// **Language is shown here but not changed here.** It belongs to the system — the app appears in
/// the Settings app with a Language row of its own, and picking there relaunches it. So this row
/// reports the current language and hands the user over, rather than offering a picker that
/// promises a live switch the platform will not honour. See `LocalizationManager` for what went
/// wrong when it did.
struct FormatSettingsSection: View {
    @Bindable var viewModel: SettingsViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            SettingsExternalRow(
                titleKey: .languageLabel,
                value: l10n.string(viewModel.language.labelKey)
            ) {
                if let systemSettingsURL {
                    openURL(systemSettingsURL)
                }
            }

            SettingsPickerRow(titleKey: .numbersLabel, selection: $viewModel.numberSystem)
            // The samples sit under the picker they belong to rather than in a group of their
            // own, so the effect of a choice is next to the choice.
            SettingsValueRow(titleKey: .settingsSampleLabel, value: viewModel.digitsSample)

            SettingsPickerRow(titleKey: .clockLabel, selection: $viewModel.clockFormat)
            SettingsValueRow(titleKey: .settingsSampleLabel, value: viewModel.clockSample)
        } header: {
            Text(l10n.string(.settingsFormatSection))
        } footer: {
            Text(l10n.string(.settingsLanguageFooter))
        }
    }

    /// Where the language actually lives on each platform.
    ///
    /// iOS hands out a per-app settings page, and `openSettingsURLString` lands directly on this
    /// app's — Language included, because the bundle ships two localizations. macOS has no
    /// per-app page, so it opens Language & Region, where applications are listed together.
    private var systemSettingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")
        #endif
    }
}

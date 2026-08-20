//
//  LanguageFormatSettingsView.swift
//  ThawabForGod
//

import SwiftUI
#if canImport(UIKit)
import UIKit // `openSettingsURLString`; MEMBER_IMPORT_VISIBILITY means SwiftUI does not re-export it
#endif

/// Language, digits and clock.
///
/// **Language is shown here but not changed here.** It belongs to the system — the app appears in
/// the Settings app with a Language row of its own, and picking there relaunches it. So this row
/// reports the current language and hands the user over, rather than offering a picker that
/// promises a live switch the platform will not honour. See `LocalizationManager` for what went
/// wrong when it did.
struct LanguageFormatSettingsView: View {
    @Bindable var viewModel: LanguageFormatSettingsViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                SettingsExternalRow(
                    titleKey: .languageLabel,
                    value: l10n.string(viewModel.language.labelKey)
                ) {
                    if let systemSettingsURL {
                        openURL(systemSettingsURL)
                    }
                }
            } footer: {
                Text(l10n.string(.settingsLanguageFooter))
            }

            Section {
                SettingsPickerRow(titleKey: .numbersLabel, selection: $viewModel.numberSystem)
                // The sample sits under the picker it belongs to rather than in a group of its
                // own, so the effect of a choice is next to the choice.
                SettingsValueRow(titleKey: .settingsSampleLabel, value: viewModel.digitsSample)
            }

            Section {
                SettingsPickerRow(titleKey: .clockLabel, selection: $viewModel.clockFormat)
                SettingsValueRow(titleKey: .settingsSampleLabel, value: viewModel.clockSample)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsFormatSection))
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

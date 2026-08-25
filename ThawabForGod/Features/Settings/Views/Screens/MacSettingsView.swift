//
//  MacSettingsView.swift
//  ThawabForGod
//

#if os(macOS)
import SwiftUI

/// Menu bar, Dock icon, and launch at login.
struct MacSettingsView: View {
    let viewModel: MacSettingsViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Form {
            Section {
                SettingsToggleRow(
                    titleKey: .settingsMenuBarShow,
                    isOn: Binding(
                        get: { viewModel.isMenuBarEnabled },
                        set: viewModel.setMenuBarEnabled
                    )
                )

                SettingsToggleRow(
                    titleKey: .settingsMenuBarOnly,
                    isOn: Binding(
                        get: { viewModel.isMenuBarOnly },
                        set: viewModel.setMenuBarOnly
                    )
                )
                // Without a status item there would be no way back to the app at all.
                .disabled(!viewModel.canHideDockIcon)

                SettingsPickerRow(
                    titleKey: .settingsMenuBarStyle,
                    selection: Binding(
                        get: { viewModel.statusStyle },
                        set: viewModel.setStatusStyle
                    )
                )
                // Nothing to style when there is no item.
                .disabled(!viewModel.canChooseStatusStyle)
            } header: {
                Text(l10n.string(.settingsMenuBarSection))
            } footer: {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(l10n.string(.settingsMenuBarFooter))
                    Text(l10n.string(.settingsMenuBarStyleFooter))
                }
            }

            Section {
                SettingsToggleRow(
                    titleKey: .settingsLaunchAtLogin,
                    isOn: Binding(
                        get: { viewModel.isLaunchAtLoginOn },
                        set: viewModel.setLaunchAtLogin
                    )
                )
                .disabled(viewModel.isLaunchAtLoginUnavailable)

                // The state this whole screen is shaped around: macOS has the request and is
                // waiting for the user to confirm it somewhere this app cannot reach.
                if viewModel.needsApproval {
                    SettingsExternalRow(
                        titleKey: .settingsLaunchAtLoginApprove,
                        value: "",
                        action: viewModel.openLoginItemsSettings
                    )
                }
            } footer: {
                Text(l10n.string(footerKey))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(l10n.string(.settingsMacSection))
        // Re-read on each appearance rather than once: this is macOS's state, not the app's, and
        // it can be changed in System Settings while this window sits open behind it.
        .task { viewModel.loadLaunchAtLogin() }
    }

    /// Three things the footer might need to say, in order of how much the reader can do about
    /// them.
    private var footerKey: L10nKey {
        if viewModel.needsApproval {
            .settingsLaunchAtLoginApprovalFooter
        } else if viewModel.isLaunchAtLoginUnavailable {
            .settingsLaunchAtLoginUnavailable
        } else if viewModel.launchAtLoginFailed {
            .settingsLaunchAtLoginFailed
        } else {
            .settingsLaunchAtLoginFooter
        }
    }
}
#endif

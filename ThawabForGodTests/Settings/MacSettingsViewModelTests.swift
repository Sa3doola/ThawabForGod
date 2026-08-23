//
//  MacSettingsViewModelTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The menu bar, the Dock icon, and the login item.
///
/// The login item half is the reason this suite exists: `requiresApproval` is a state a `Bool`
/// cannot hold, and getting it wrong produces a switch that flips itself back with no
/// explanation.
@MainActor
struct MacSettingsViewModelTests {

    private func makeViewModel(
        store: InMemorySettingsStore = InMemorySettingsStore(),
        loginItem: FakeLaunchAtLogin = FakeLaunchAtLogin(),
        onMenuBarChanged: @escaping () -> Void = {}
    ) -> MacSettingsViewModel {
        MacSettingsViewModel(
            preferences: MenuBarPreferences(settingsStore: store),
            loginItem: loginItem,
            onMenuBarChanged: onMenuBarChanged
        )
    }

    // MARK: Defaults

    /// The two point opposite ways on purpose: a glanceable countdown is most of what a Mac build
    /// is for, while an app that vanished from the Dock on its own would look like it had quit.
    @Test func theStatusItemIsOnByDefaultAndTheDockIconStays() {
        let viewModel = makeViewModel()

        #expect(viewModel.isMenuBarEnabled)
        #expect(!viewModel.isMenuBarOnly)
    }

    /// Neither default is written. An unset key means "never opinionated", which is what lets a
    /// later release change what the default *is* — the rule `SettingsStore` states.
    @Test func nothingIsWrittenUntilSomethingIsChanged() {
        let store = InMemorySettingsStore()
        _ = makeViewModel(store: store)

        #expect(store.bool(for: .menuBarEnabled) == nil)
        #expect(store.bool(for: .menuBarOnly) == nil)
    }

    // MARK: The pairing that prevents a dead end

    /// With no status item and no Dock icon there is no way back to the app at all. The switch is
    /// disabled rather than allowed to strand anyone.
    @Test func hidingTheDockIconNeedsTheStatusItem() {
        let viewModel = makeViewModel()
        #expect(viewModel.canHideDockIcon)

        viewModel.setMenuBarEnabled(false)

        #expect(!viewModel.canHideDockIcon)
    }

    /// And the reverse order, which the view cannot guard: turning the status item off while the
    /// Dock icon is already hidden has to bring the icon back.
    @Test func turningOffTheStatusItemRestoresTheDockIcon() {
        let viewModel = makeViewModel()
        viewModel.setMenuBarOnly(true)
        #expect(viewModel.isMenuBarOnly)

        viewModel.setMenuBarEnabled(false)

        #expect(!viewModel.isMenuBarOnly)
    }

    @Test func changingEitherPreferenceTellsTheController() {
        var applied = 0
        let viewModel = makeViewModel(onMenuBarChanged: { applied += 1 })

        viewModel.setMenuBarEnabled(false)
        viewModel.setMenuBarOnly(false)

        #expect(applied == 2)
    }

    // MARK: Launch at login

    @Test func itReadsTheStatusRatherThanAssumingIt() {
        let loginItem = FakeLaunchAtLogin(status: .enabled)
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.loadLaunchAtLogin()

        #expect(viewModel.isLaunchAtLoginOn)
        #expect(!viewModel.needsApproval)
    }

    /// The state the whole screen is shaped around. Registration succeeded, macOS is waiting for
    /// the user, and the switch reads *on* — because they asked for it — with a row that explains
    /// why nothing has happened yet.
    @Test func approvalPendingReadsAsOnAndOffersTheWayToFinish() {
        let loginItem = FakeLaunchAtLogin()
        loginItem.statusAfterEnable = .requiresApproval
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.setLaunchAtLogin(true)

        #expect(viewModel.isLaunchAtLoginOn)
        #expect(viewModel.needsApproval)
        #expect(!viewModel.launchAtLoginFailed)
    }

    @Test func theApprovalRowOpensSystemSettings() {
        let loginItem = FakeLaunchAtLogin(status: .requiresApproval)
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.openLoginItemsSettings()

        #expect(loginItem.openedSystemSettings)
    }

    /// A refused registration leaves the switch off and says so. The commonest cause is one the
    /// user can act on — the app is not in `/Applications`.
    @Test func aRefusedRegistrationLeavesTheSwitchOff() {
        let loginItem = FakeLaunchAtLogin()
        loginItem.enableError = LoginItemError()
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.setLaunchAtLogin(true)

        #expect(!viewModel.isLaunchAtLoginOn)
        #expect(viewModel.launchAtLoginFailed)
    }

    /// And a later success clears the failure, rather than leaving a stale warning under a switch
    /// that now works.
    @Test func aLaterSuccessClearsTheFailure() {
        let loginItem = FakeLaunchAtLogin()
        loginItem.enableError = LoginItemError()
        let viewModel = makeViewModel(loginItem: loginItem)
        viewModel.setLaunchAtLogin(true)

        loginItem.enableError = nil
        viewModel.setLaunchAtLogin(true)

        #expect(viewModel.isLaunchAtLoginOn)
        #expect(!viewModel.launchAtLoginFailed)
    }

    @Test func turningItOffUnregisters() {
        let loginItem = FakeLaunchAtLogin(status: .enabled)
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.setLaunchAtLogin(false)

        #expect(loginItem.disableCount == 1)
        #expect(!viewModel.isLaunchAtLoginOn)
    }

    /// A debug build is not in `/Applications`, so `SMAppService` cannot answer. Saying so beats
    /// a switch that silently refuses to move.
    @Test func anUnavailableServiceIsReportedRatherThanShownAsOff() {
        let viewModel = makeViewModel(loginItem: FakeLaunchAtLogin(status: .unavailable))

        viewModel.loadLaunchAtLogin()

        #expect(viewModel.isLaunchAtLoginUnavailable)
        #expect(!viewModel.isLaunchAtLoginOn)
    }
}

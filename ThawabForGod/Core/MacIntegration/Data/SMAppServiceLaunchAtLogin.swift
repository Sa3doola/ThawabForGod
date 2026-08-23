//
//  SMAppServiceLaunchAtLogin.swift
//  ThawabForGod
//

#if os(macOS)
import Foundation
import ServiceManagement

/// `SMAppService.mainApp` behind `LaunchAtLoginServicing` — the only file in the app that imports
/// ServiceManagement.
///
/// **It does not work from a build folder.** `SMAppService` identifies the app by its location
/// and code signature, so `register()` from DerivedData throws or registers something the user
/// cannot approve. Testing this means a Release build copied into `/Applications` and launched
/// from there; `unavailable` is what a debug run will usually report, and that is correct rather
/// than a bug.
@MainActor
final class SMAppServiceLaunchAtLogin: LaunchAtLoginServicing {

    init() {}

    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func enable() throws {
        // Registering something already registered throws, and the user's intent is satisfied
        // either way — including in `requiresApproval`, where re-registering would do nothing
        // except produce an error the screen would have to explain.
        guard SMAppService.mainApp.status != .enabled,
              SMAppService.mainApp.status != .requiresApproval else {
            return
        }

        try SMAppService.mainApp.register()
    }

    func disable() throws {
        guard SMAppService.mainApp.status != .notRegistered else { return }

        try SMAppService.mainApp.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
#endif

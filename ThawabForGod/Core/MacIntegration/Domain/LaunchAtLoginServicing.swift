//
//  LaunchAtLoginServicing.swift
//  ThawabForGod
//

import Foundation

/// Whether macOS starts Noor when the user logs in.
///
/// Four states, not a `Bool`, and `requiresApproval` is the reason. macOS records the app's
/// request but does not act on it until the user confirms in **System Settings → General →
/// Login Items**, and an app that modelled this as on/off would draw a switch that flips back by
/// itself with no explanation. The state exists precisely so the screen can say what happened
/// and offer the way to finish it.
nonisolated enum LaunchAtLoginStatus: Equatable, Sendable {

    /// Registered and approved. The app will start at login.
    case enabled

    /// Not registered. The normal "off".
    case disabled

    /// Registered, and waiting for the user to allow it in System Settings.
    case requiresApproval

    /// The service could not answer — the app is not where macOS expects it to be, which in
    /// practice means it is being run from a build folder rather than `/Applications`.
    case unavailable

    /// What the switch should show. `requiresApproval` reads as *on*, because the user has asked
    /// for it: the row's job is then to explain why it has not taken effect, not to pretend the
    /// request was never made.
    var isOn: Bool {
        switch self {
        case .enabled, .requiresApproval: true
        case .disabled, .unavailable: false
        }
    }
}

/// Registering the app as a login item.
///
/// A protocol so Domain never imports ServiceManagement — the same trade `NotificationService`
/// makes with UserNotifications, and for the same reason: `SMAppService` is a system singleton
/// with real side effects on the user's machine, and no test may touch it.
@MainActor
protocol LaunchAtLoginServicing: AnyObject {

    /// Read fresh each time. The user can revoke this in System Settings while the app is
    /// running, so a value cached at construction would be a lie by the time anybody looked.
    var status: LaunchAtLoginStatus { get }

    func enable() throws
    func disable() throws

    /// Opens the Login Items page, which is the only place `requiresApproval` can be resolved.
    func openSystemSettings()
}

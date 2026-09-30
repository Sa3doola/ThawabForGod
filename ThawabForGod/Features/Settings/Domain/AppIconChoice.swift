//
//  AppIconChoice.swift
//  ThawabForGod
//

import Foundation

/// The icons a reader can put on their Home Screen.
///
/// One case per Icon Composer bundle in `Resources/`, and declaration order is the order the
/// picker shows them. The default comes first because it is the icon the app ships with, and
/// the one a reader who changes their mind is looking for.
///
/// There is no `SettingsKey` behind this. Which icon is current is the *system's* to remember:
/// `UIApplication.alternateIconName` survives relaunches on its own, and a stored copy would be a
/// second source of truth that could only ever disagree with the Home Screen.
nonisolated enum AppIconChoice: String, CaseIterable, Identifiable, Sendable {
    case `default`
    case green
    case night
    case sand

    var id: String { rawValue }

    /// Reads the system's answer back as a case.
    ///
    /// A name this build does not know falls back to `.default` rather than to `nil`: it can only
    /// be an icon withdrawn by an update, and iOS itself shows the primary icon in that case — so
    /// the picker marking the default is the picker telling the truth about the Home Screen.
    init(alternateIconName: String?) {
        self = Self.allCases.first { $0.alternateIconName == alternateIconName } ?? .default
    }

    /// The name `setAlternateIconName(_:)` takes: the `.icon` bundle's name, and `nil` for the
    /// primary icon.
    ///
    /// These must match `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`, which is set by
    /// `Tools/add_alternate_app_icons.rb`. Nothing but `AppIconTests` checks the two against each
    /// other — iOS refuses a name the Info.plist does not list, and says so only at run time.
    var alternateIconName: String? {
        switch self {
        case .default: nil
        case .green: "AppIcon-Green"
        case .night: "AppIcon-Night"
        case .sand: "AppIcon-Sand"
        }
    }

    /// The picture the picker draws. An alternate icon is not an image the app can load, so these
    /// are exported from the same `.icon` bundles by `Tools/IconBuilder/export_icon_previews.sh`.
    var previewAssetName: String {
        switch self {
        case .default: "AppIconImages/IconPreview-Default"
        case .green: "AppIconImages/IconPreview-Green"
        case .night: "AppIconImages/IconPreview-Night"
        case .sand: "AppIconImages/IconPreview-Sand"
        }
    }

    var labelKey: L10nKey {
        switch self {
        case .default: .appIconDefault
        case .green: .appIconGreen
        case .night: .appIconNight
        case .sand: .appIconSand
        }
    }
}

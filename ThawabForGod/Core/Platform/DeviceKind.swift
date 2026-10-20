//
//  DeviceKind.swift
//  ThawabForGod
//

#if canImport(UIKit)
import UIKit
#endif

/// What kind of device the app runs on, for the few behaviours that belong to one kind of device
/// rather than to a size: the Quran pager's tap-to-toggle chrome, and the settings that only an iPhone has
/// (landscape layout, opening a foldable flat).
///
/// **Never for layout.** A layout follows the size, the size classes and the fold — an iPad in
/// Split View is narrower than some phones. Ported from Mushaf.
enum DeviceKind {
    /// An iPhone, a foldable one included.
    @MainActor static var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
}

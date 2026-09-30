//
//  ChromeTypography.swift
//  ThawabForGod
//

#if os(iOS)
import UIKit

/// Plex in the parts of the screen SwiftUI's `.font` never reaches: the navigation bar's titles
/// and the tab bar's labels, both of which UIKit draws itself.
///
/// Set through the appearance proxies' plain attribute properties rather than by installing a
/// `UINavigationBarAppearance`, and that is deliberate. An installed appearance object replaces
/// the *whole* bar configuration — background, blur, shadow — and on a system that draws its bars
/// in glass it would swap the platform's material for whatever the object was configured with.
/// The attribute properties change the type and leave everything else to the system.
///
/// Each face goes through `UIFontMetrics` for its text style, so the chrome grows with Dynamic
/// Type the way the system's own face did. Colours are left out of every dictionary on purpose:
/// a missing key keeps the system's colour, which is what follows light and dark.
///
/// macOS has no equivalent and gets none: its window chrome is the system's to draw, and a Mac
/// app that restyled its title bar would look like it was pretending to be something else.
enum ChromeTypography {

    /// Call once, after `FontRegistrar` — a name that has not been registered yet resolves to
    /// `nil` here, and the bars keep the system face.
    static func apply() {
        let navigationBar = UINavigationBar.appearance()

        if let title = font(.semiBold, size: 17, textStyle: .headline) {
            navigationBar.titleTextAttributes = [.font: title]
        }
        if let largeTitle = font(.bold, size: 34, textStyle: .largeTitle) {
            navigationBar.largeTitleTextAttributes = [.font: largeTitle]
        }
        if let tabTitle = font(.medium, size: 10, textStyle: .caption2) {
            let tabItem = UITabBarItem.appearance()
            tabItem.setTitleTextAttributes([.font: tabTitle], for: .normal)
            tabItem.setTitleTextAttributes([.font: tabTitle], for: .selected)
        }
    }

    private static func font(
        _ weight: PlexAppFont.Weight,
        size: CGFloat,
        textStyle: UIFont.TextStyle
    ) -> UIFont? {
        UIFont(name: weight.postScriptName, size: size).map {
            UIFontMetrics(forTextStyle: textStyle).scaledFont(for: $0)
        }
    }
}
#endif

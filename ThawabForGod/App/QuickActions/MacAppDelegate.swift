//
//  MacAppDelegate.swift
//  ThawabForGod
//

#if os(macOS)
import AppKit

/// The Mac's answer to a long press on the app icon: the same list, in the Dock menu.
///
/// `AppQuickAction` is read here unchanged, so the two platforms cannot drift — an action added
/// for the iPhone appears on the Mac in the same release, in the same order, without anybody
/// having to remember this file exists.
///
/// One difference is deliberate: the Dock menu shows *every* available action, not four.
/// `AppQuickAction.maximumVisible` is a limit iOS imposes on the Home Screen, and carrying it
/// onto a menu that has no such limit would be this app inventing a constraint the platform does
/// not have.
final class MacAppDelegate: NSObject, NSApplicationDelegate {

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        for action in AppQuickAction.allCases where action.isAvailable {
            let item = NSMenuItem(
                title: title(action.titleKey),
                action: #selector(openQuickAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.image = NSImage(systemSymbolName: action.symbol, accessibilityDescription: nil)
            item.representedObject = action.link.url.absoluteString
            menu.addItem(item)
        }

        return menu
    }

    @objc
    private func openQuickAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let link = URL(string: raw).flatMap(DeepLink.init(url:)),
              let inbox = DeepLinkInbox.current else {
            return
        }

        inbox.receive(link)
    }

    /// The label, resolved straight from the bundle rather than through `LocalizationManager`.
    ///
    /// The manager is the app's rule and it is not being bent here: the key is still an
    /// `L10nKey`, so a missing string is still a compile error. What the manager adds on top —
    /// digits and hour cycle — a menu title has none of, and what it cannot add is a language,
    /// because the language is the *process's* by design (see `Core/Localization`). AppKit
    /// constructs this delegate with no argument list to inject the manager through, and
    /// publishing a second static to reach it would cost more than it buys.
    private func title(_ key: L10nKey) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .main)
    }
}
#endif

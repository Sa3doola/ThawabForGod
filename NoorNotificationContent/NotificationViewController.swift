//
//  NotificationViewController.swift
//  NoorNotificationContent
//

import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// The expanded notification: what a reader sees when they pull a reminder down.
///
/// **The collapsed banner is not this.** iOS renders that one itself, and the only things it takes
/// from an app are three lines of text and one attachment thumbnail — which is why
/// `LocalizedReminderContent` spends its title on the prayer and its subtitle on the time, and why
/// `ReminderArtwork` exists at all. Everything below is the *expanded* view, and it is the only
/// part of a notification this app draws.
///
/// A `UIViewController` because the extension point requires one; the controller does nothing but
/// host SwiftUI and decode the payload. `UNNotificationExtensionDefaultContentHidden` is `YES` in
/// the plist, so nothing of Apple's layout is drawn underneath — the card repeats the title and
/// the body precisely because it has replaced them.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {

    /// The card's state, owned here and observed by the hosted view.
    ///
    /// A reference type because `didReceive(_:)` arrives after the hosting controller has been
    /// installed: the view is on screen before there is anything to draw in it, and rebuilding the
    /// hierarchy at that point would flash.
    private let model = ReminderCardModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let host = UIHostingController(rootView: ReminderCardView(model: model))

        // The card paints its own ground — the prayer's `DayRamp` stop — so the hosting
        // controller's default white must not sit in front of it while the payload is decoded.
        host.view.backgroundColor = .clear

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        host.didMove(toParent: self)
    }

    /// Called once per notification, with whatever `userInfo` was scheduled.
    ///
    /// A payload this build cannot read leaves `presentation` at `nil`, and the card falls back to
    /// the notification's own already-localized strings. That is not a theoretical case: iOS keeps
    /// delivered notifications across app updates, so this can be handed a dictionary written by a
    /// version that no longer exists — the same promise `DeepLink` makes about cached shortcut
    /// items, one process further out.
    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content

        model.presentation = ReminderPresentation(userInfo: content.userInfo)
        model.title = content.title
        model.body = content.body
    }
}

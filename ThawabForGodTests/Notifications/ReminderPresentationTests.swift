//
//  ReminderPresentationTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The payload a delivered notification carries into the content extension.
///
/// Worth a suite of its own because it is the one piece of this slice that crosses a process
/// boundary *and* a version boundary: iOS keeps delivered notifications across app updates, so a
/// card can be opened on a dictionary written by a build that no longer exists. Every failure here
/// has to be `nil` rather than a guess.
@MainActor
struct ReminderPresentationTests {

    private let date = Date(timeIntervalSince1970: 1_780_000_000)

    private func presentation(_ prayer: Prayer = .maghrib) -> ReminderPresentation {
        ReminderPresentation(subject: .prayer(prayer), date: date, body: "It's time to pray.")
    }

    // MARK: Round trip

    @Test func payloadSurvivesTheTrip() throws {
        let original = presentation()

        let decoded = try #require(ReminderPresentation(userInfo: original.userInfo))

        #expect(decoded == original)
    }

    @Test(arguments: Prayer.allCases)
    func everyPrayerRoundTrips(prayer: Prayer) throws {
        let decoded = try #require(
            ReminderPresentation(userInfo: presentation(prayer).userInfo)
        )

        #expect(decoded.subject == .prayer(prayer))
    }

    /// `userInfo` is serialized by the system, and a value it cannot encode is dropped rather than
    /// reported — so the payload has to be property-list types all the way down.
    @Test func payloadIsPropertyListEncodable() {
        #expect(PropertyListSerialization.propertyList(
            presentation().userInfo, isValidFor: .binary
        ))
    }

    // MARK: Refusing to guess

    @Test func aPrayerThisBuildDoesNotKnowIsNotDecoded() {
        var info = presentation().userInfo
        info["noor.reminder.prayer"] = "tahajjud"

        #expect(ReminderPresentation(userInfo: info) == nil)
    }

    @Test func aCategoryThisBuildDoesNotKnowIsNotDecoded() {
        var info = presentation().userInfo
        info["noor.reminder.category"] = "adhkar"

        #expect(ReminderPresentation(userInfo: info) == nil)
    }

    @Test(arguments: [
        "noor.reminder.category", "noor.reminder.prayer", "noor.reminder.date", "noor.reminder.body"
    ])
    func aMissingFieldIsNotDecoded(key: String) {
        var info = presentation().userInfo
        info.removeValue(forKey: key)

        #expect(ReminderPresentation(userInfo: info) == nil)
    }

    @Test func anEmptyPayloadIsNotDecoded() {
        #expect(ReminderPresentation(userInfo: [:]) == nil)
    }

    // MARK: The plist contract

    /// The identifier is written by hand into the content extension's `Info.plist`, under
    /// `UNNotificationExtensionCategory`, where no compiler can check it against this enum. This
    /// test is the check — if it fails, the plist is the other half that has to move.
    @Test func categoryIdentifierIsTheOneTheExtensionDeclares() {
        #expect(ReminderCategory.prayer.identifier == "noor.reminder.prayer")
    }

    @Test func categoriesRoundTripThroughTheirIdentifiers() {
        for category in ReminderCategory.allCases {
            #expect(ReminderCategory(identifier: category.identifier) == category)
        }
    }

    @Test func anUnknownIdentifierIsNotACategory() {
        #expect(ReminderCategory(identifier: "noor.reminder.something-else") == nil)
    }
}

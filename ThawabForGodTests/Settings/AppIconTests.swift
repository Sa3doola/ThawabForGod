//
//  AppIconTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod
#if os(iOS)
import UIKit
#endif

/// The app icon picker: the view model's handling of the system's answer, and the two contracts
/// no compiler checks — the alternate names against the built Info.plist, and the preview names
/// against the asset catalog.
@MainActor
struct AppIconTests {

    private struct Refusal: Error {}

    /// Stands in for `UIApplication`: remembers the name it was asked for, or refuses.
    private final class FakeAppIconSwitcher: AppIconSwitching {
        var supportsAlternateIcons = true
        var currentAlternateIconName: String?
        var shouldFail = false
        private(set) var requests: [String?] = []

        init(current: String? = nil) {
            currentAlternateIconName = current
        }

        func setAlternateIconName(_ name: String?) async throws {
            requests.append(name)
            if shouldFail { throw Refusal() }
            currentAlternateIconName = name
        }
    }

    private func makeViewModel(
        _ switcher: FakeAppIconSwitcher?
    ) -> AppearanceSettingsViewModel {
        AppearanceSettingsViewModel(
            theme: ThemeManager(settingsStore: InMemorySettingsStore()),
            appIcons: switcher
        )
    }

    // MARK: - Reading the system's answer

    @Test func seedsFromTheIconInEffect() {
        #expect(makeViewModel(FakeAppIconSwitcher(current: "AppIcon-Night")).appIcon == .night)
        #expect(makeViewModel(FakeAppIconSwitcher(current: nil)).appIcon == .default)
    }

    /// An icon withdrawn by an update: iOS shows the primary icon, so the picker must too.
    @Test func anUnknownIconNameReadsAsTheDefault() {
        #expect(AppIconChoice(alternateIconName: "AppIcon-Withdrawn") == .default)
    }

    @Test func everyChoiceRoundTripsThroughItsName() {
        for choice in AppIconChoice.allCases {
            #expect(AppIconChoice(alternateIconName: choice.alternateIconName) == choice)
        }
    }

    // MARK: - Whether there is anything to offer

    @Test func offersEveryIconWhereTheSystemAllowsIt() {
        #expect(makeViewModel(FakeAppIconSwitcher()).iconChoices == AppIconChoice.allCases)
    }

    @Test func offersNothingWithoutASwitcher() {
        #expect(makeViewModel(nil).iconChoices.isEmpty)
    }

    @Test func offersNothingWhereTheSystemRefusesAlternateIcons() {
        let switcher = FakeAppIconSwitcher()
        switcher.supportsAlternateIcons = false
        #expect(makeViewModel(switcher).iconChoices.isEmpty)
    }

    // MARK: - Changing it

    @Test func selectingAnIconAsksTheSystemForItsName() async {
        let switcher = FakeAppIconSwitcher()
        let viewModel = makeViewModel(switcher)

        await viewModel.selectIcon(.sand)

        #expect(switcher.requests == ["AppIcon-Sand"])
        #expect(viewModel.appIcon == .sand)
        #expect(!viewModel.isChangingIcon)
        #expect(!viewModel.iconChangeFailed)
    }

    /// The primary icon is `nil`, not a name — iOS has no bundle called "default".
    @Test func returningToTheDefaultAsksForNil() async {
        let switcher = FakeAppIconSwitcher(current: "AppIcon-Green")
        let viewModel = makeViewModel(switcher)

        await viewModel.selectIcon(.default)

        #expect(switcher.requests == [nil])
        #expect(viewModel.appIcon == .default)
    }

    @Test func selectingTheCurrentIconDoesNotAskAgain() async {
        let switcher = FakeAppIconSwitcher(current: "AppIcon-Night")
        let viewModel = makeViewModel(switcher)

        await viewModel.selectIcon(.night)

        #expect(switcher.requests.isEmpty)
    }

    @Test func aRefusalPutsTheSelectionBackAndSaysSo() async {
        let switcher = FakeAppIconSwitcher(current: "AppIcon-Green")
        switcher.shouldFail = true
        let viewModel = makeViewModel(switcher)

        await viewModel.selectIcon(.night)

        #expect(viewModel.appIcon == .green)
        #expect(viewModel.iconChangeFailed)
        #expect(!viewModel.isChangingIcon)
    }

    // MARK: - The contracts

    #if os(iOS)
    /// The names in `AppIconChoice` against the names actool wrote into the built app.
    ///
    /// The list lives in two places — the enum, and the build setting
    /// `Tools/add_alternate_app_icons.rb` writes — and iOS refuses a name the Info.plist does not
    /// carry only at run time, as an error the reader sees. This is the one place they meet.
    @Test func everyAlternateIconIsDeclaredInTheBuiltApp() throws {
        let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let alternates = try #require(icons["CFBundleAlternateIcons"] as? [String: Any])

        let expected = Set(AppIconChoice.allCases.compactMap(\.alternateIconName))
        #expect(Set(alternates.keys) == expected)
    }

    /// A missing preview draws an empty tile rather than failing, so it would ship unnoticed.
    @Test func everyChoiceHasAPreview() {
        for choice in AppIconChoice.allCases {
            #expect(UIImage(named: choice.previewAssetName) != nil, "No preview for \(choice)")
        }
    }
    #endif
}

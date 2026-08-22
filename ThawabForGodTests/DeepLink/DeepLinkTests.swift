//
//  DeepLinkTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// The app's promise to everything outside it.
///
/// A `DeepLink` is not internal wiring — it is baked into shortcut items the system caches and
/// into widgets rendered by another process, both of which can outlive the build that made them.
/// So the two properties this suite pins are the ones that make that promise keepable: every
/// destination survives the round trip through a URL unchanged, and nothing that arrives from
/// outside can produce a wrong answer or a crash.
struct DeepLinkTests {

    /// Every case, listed by hand rather than derived.
    ///
    /// `DeepLink` is deliberately not `CaseIterable` — one of its cases carries a payload — and
    /// writing the list out is what makes adding a case a *decision* to come back here, rather
    /// than something a generated collection quietly absorbs.
    private static let all: [DeepLink] = [
        .home,
        .prayerTimes,
        .qibla,
        .tasbih,
        .names,
        .adhkar,
        .adhkarCategory(.morning),
        .adhkarCategory(.evening),
        .quran,
        .hadith,
        .settings
    ]

    // MARK: The round trip

    @Test(arguments: DeepLinkTests.all)
    func everyDestinationSurvivesTheRoundTrip(_ link: DeepLink) {
        #expect(DeepLink(url: link.url) == link)
    }

    /// Distinct destinations must produce distinct URLs, or two of them would collapse onto one
    /// and a shortcut would open the wrong screen. The round trip above cannot catch that on its
    /// own — a link that decoded to itself would still pass while shadowing another.
    @Test func everyDestinationHasAUrlOfItsOwn() {
        let urls = Set(Self.all.map(\.url.absoluteString))

        #expect(urls.count == Self.all.count)
    }

    @Test func theSchemeIsTheOneDeclaredInTheBundle() {
        for link in Self.all {
            #expect(link.url.scheme == "noor")
        }
    }

    // MARK: What arrives from outside

    /// The host is the destination, so a host this build has never heard of is not a link.
    @Test func anUnknownHostIsNotALink() {
        #expect(DeepLink(url: URL(string: "noor://nonsense")!) == nil)
    }

    @Test func anotherAppsSchemeIsNotALink() {
        #expect(DeepLink(url: URL(string: "https://qibla")!) == nil)
        #expect(DeepLink(url: URL(string: "noorish://qibla")!) == nil)
    }

    /// URL hosts are case-insensitive by definition, so `NOOR://Qibla` is the same link. A
    /// shortcut typed by hand, or normalised by something between here and the system, still has
    /// to land.
    @Test func caseDoesNotChangeWhatALinkMeans() {
        #expect(DeepLink(url: URL(string: "NOOR://Qibla")!) == .qibla)
        #expect(DeepLink(url: URL(string: "noor://ADHKAR?period=MORNING")!) == .adhkarCategory(.morning))
    }

    /// A URL with no authority at all. The parse has to answer "no", not reach past the end of
    /// an empty string.
    @Test func aUrlWithNoHostIsNotALink() {
        #expect(DeepLink(url: URL(string: "noor://")!) == nil)
        #expect(DeepLink(url: URL(string: "noor:")!) == nil)
        #expect(DeepLink(url: URL(string: "noor:///qibla")!) == nil)
    }

    /// The one case with a payload, and the one place a partial answer is better than none.
    ///
    /// A period this build does not recognise still clearly means "the adhkar" — most likely a
    /// category a later release ships and this one does not. Falling back to the list keeps the
    /// reader one tap away; returning `nil` would strand them on whatever screen they were on.
    @Test func anUnrecognisedPeriodFallsBackToTheAdhkarList() {
        #expect(DeepLink(url: URL(string: "noor://adhkar?period=afterprayer")!) == .adhkar)
        #expect(DeepLink(url: URL(string: "noor://adhkar?period=")!) == .adhkar)
        #expect(DeepLink(url: URL(string: "noor://adhkar")!) == .adhkar)
    }

    /// A query on a link that has no payload is ignored rather than treated as a mismatch.
    @Test func anIrrelevantQueryIsIgnored() {
        #expect(DeepLink(url: URL(string: "noor://qibla?period=morning&x=1")!) == .qibla)
    }

    @Test func aTrailingSlashIsStillTheSameHost() {
        #expect(DeepLink(url: URL(string: "noor://prayer-times/")!) == .prayerTimes)
    }
}

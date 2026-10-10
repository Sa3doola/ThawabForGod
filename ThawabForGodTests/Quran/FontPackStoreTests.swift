//
//  FontPackStoreTests.swift
//  ThawabForGodTests
//

import CoreText
import Foundation
import Testing
@testable import ThawabForGod

/// The page-font registration window (the current page ± 3 registered, more than 20 pages away
/// unregistered) and the page-font store that applies it.
///
/// The window maths is pure and runs in every clone. The store is exercised two ways: against a
/// temp folder with no page fonts, which every clone can run, and against the app bundle's
/// `madaniV2` folder, which only exists where the full data was built, so those cases are guarded.
/// Font registration is process-wide, so the suite is serialized.
@Suite(.serialized)
struct FontPackStoreTests {
    let window = FontRegistrationWindow.standard
    let style = MushafStyle.madaniV2

    static func resolves(_ name: String) -> Bool {
        CTFontCopyPostScriptName(CTFontCreateWithName(name as CFString, 12, nil)) as String == name
    }

    // MARK: Window

    @Test func wantsTheCurrentPageFirstThenTheNearest() {
        #expect(window.wanted(around: 50, pages: style.pages) == [50, 51, 49, 52, 48, 53, 47])
        #expect(window.wanted(around: 1, pages: style.pages) == [1, 2, 3, 4])
        #expect(window.wanted(around: 604, pages: style.pages) == [604, 603, 602, 601])
    }

    @Test func dropsOnlyPagesMoreThanTwentyAway() {
        let plan = window.plan(around: 30, registered: Set(1...12), pages: style.pages)
        #expect(plan.unregister == Array(1...9))
        #expect(plan.register == [30, 31, 29, 32, 28, 33, 27])
        #expect(window.plan(around: 30, registered: Set(27...33), pages: style.pages) == ([], []))
    }

    /// Paging 1→604 (and jumping back) never holds more than 2 × 20 + 1 fonts.
    @Test func registeredSetStaysBoundedWhilePaging() {
        var registered = Set<Int>()
        var largest = 0
        for page in Array(style.pages) + [1, 300, 604] {
            let plan = window.plan(around: page, registered: registered, pages: style.pages)
            registered.formUnion(plan.register)
            registered.subtract(plan.unregister)
            largest = max(largest, registered.count)
            #expect(registered.allSatisfy { abs($0 - page) <= window.keepDistance })
            #expect(window.wanted(around: page, pages: style.pages).allSatisfy(registered.contains))
        }
        #expect(largest <= 2 * window.keepDistance + 1)
    }

    @Test func pageFontNaming() throws {
        let pack = try #require(style.pageFonts)
        #expect(pack.fileName(page: 7) == "p7")
        #expect(pack.postScriptName(page: 7) == "QCF2007")
        #expect(pack.postScriptName(page: 604) == "QCF2604")
    }

    // MARK: Store without page fonts (every clone)

    @Test func emptyStoreHasNothing() async {
        let store = FontPackStore(root: nil)
        await store.ensureRegistered(around: 1, style: style)
        #expect(store.registeredPages(style: .madaniV2).isEmpty)
    }

    /// A root with no `madaniV2` folder in it marks each page unavailable rather than registering
    /// or crashing, and the page reads as `.unavailable` (the Unicode renderer), not `.pending`.
    @Test func aRootWithoutPageFontsMarksThePagesUnavailable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("fontpack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = FontPackStore(root: root, window: FontRegistrationWindow(radius: 1, keepDistance: 20))
        await store.ensureRegistered(around: 300, style: style)

        #expect(store.registeredPages(style: .madaniV2).isEmpty)
        #expect(store.status(page: 300, style: .madaniV2) == .unavailable)
        #expect(store.status(page: 301, style: .madaniV2) == .unavailable)
    }

    // MARK: Bundled store (needs the full data)

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func theBundleHoldsAll604PageFontsInTheirFolder() throws {
        let folder = try #require(Bundle.main.resourceURL).appendingPathComponent(QuranPageFonts.folderName)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".ttf") }
        #expect(Set(files) == Set(style.pages.map { "p\($0).ttf" }))
    }

    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func registersTheWindowAndUnregistersFarPages() async {
        let store = FontPackStore()
        await store.ensureRegistered(around: 300, style: style)
        #expect(store.registeredPages(style: .madaniV2) == Set(297...303))
        #expect(store.isRegistered(page: 300, style: .madaniV2))
        #expect(Self.resolves("QCF2300"))

        await store.ensureRegistered(around: 330, style: style)
        // 297…303 are all more than 20 pages from 330.
        #expect(store.registeredPages(style: .madaniV2) == Set(327...333))
        #expect(!store.isRegistered(page: 300, style: .madaniV2))
        #expect(!Self.resolves("QCF2300"))
        #expect(Self.resolves("QCF2330"))

        await store.ensureRegistered(around: 600, style: style)
        #expect(store.registeredPages(style: .madaniV2) == Set(597...603))
        Self.unregister(store.registeredPages(style: .madaniV2))
    }

    /// Registration is process-wide and the store has no "forget everything": a test that leaves
    /// fonts registered leaves them for every other suite in the process.
    static func unregister(_ pages: Set<Int>) {
        guard let folder = Bundle.main.resourceURL?.appendingPathComponent(QuranPageFonts.folderName) else { return }
        for page in pages {
            CTFontManagerUnregisterFontsForURL(folder.appendingPathComponent("p\(page).ttf") as CFURL, .process, nil)
        }
    }

    /// A missing file or a file with another page's font is never registered: the page falls
    /// back to the Unicode renderer and the wrong font never shadows the real one.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func missingOrMislabelledFontsAreUnavailable() async throws {
        let bundled = try #require(Bundle.main.resourceURL).appendingPathComponent(QuranPageFonts.folderName)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("fontpack-\(UUID().uuidString)")
        let folder = root.appendingPathComponent(QuranPageFonts.folderName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.copyItem(at: bundled.appendingPathComponent("p450.ttf"), to: folder.appendingPathComponent("p450.ttf"))
        try FileManager.default.copyItem(at: bundled.appendingPathComponent("p452.ttf"), to: folder.appendingPathComponent("p451.ttf"))

        let store = FontPackStore(root: root, window: FontRegistrationWindow(radius: 1, keepDistance: 20))
        await store.ensureRegistered(around: 450, style: style)
        #expect(store.registeredPages(style: .madaniV2) == [450])
        #expect(!store.isRegistered(page: 449, style: .madaniV2))   // missing
        #expect(!store.isRegistered(page: 451, style: .madaniV2))   // holds QCF2452
        #expect(!Self.resolves("QCF2452"))
        // Asking again does not retry the unavailable pages.
        await store.ensureRegistered(around: 450, style: style)
        #expect(store.registeredPages(style: .madaniV2) == [450])
        await store.ensureRegistered(around: 500, style: style)
        #expect(store.registeredPages(style: .madaniV2).isEmpty)
    }
}

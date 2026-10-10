//
//  FontPackStore.swift
//  ThawabForGod
//

import CoreText
import Foundation
import OSLog
import os

/// `FontPackStoring` over the page fonts in the app bundle's `QuranPageFonts.folderName` folder.
///
/// Ported from Mushaf's `BundledFontPackStore` with its isolation exactly as it was (T13): an actor
/// does the registering, off the main actor, while `status(page:style:)` is `nonisolated` and reads
/// an `OSAllocatedUnfairLock`, so a page view can ask synchronously, on the main actor, whether to
/// draw glyphs or fall back to the Unicode renderer. Injected by `AppContainer` rather than shared
/// as a global.
///
/// In a clone without the full data the folder holds only its README, so every page is
/// `.unavailable` — and Mushaf mode is hidden there anyway (`QuranCapabilities`).
actor FontPackStore: FontPackStoring {
    private let root: URL?
    private let window: FontRegistrationWindow
    private struct State {
        var registered: [MushafStyleID: Set<Int>] = [:]
        /// Missing or with the wrong PostScript name: never retried.
        var unavailable: [MushafStyleID: Set<Int>] = [:]
    }

    /// Read synchronously by views; written only by this actor. Invariant: nothing suspends inside
    /// `withLock`.
    private nonisolated let state = OSAllocatedUnfairLock(initialState: State())

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ThawabForGod", category: "QuranFonts"
    )

    /// - Parameter root: folder holding the pack directories; the bundle's resources by default.
    init(root: URL? = Bundle.main.resourceURL, window: FontRegistrationWindow = .standard) {
        self.root = root
        self.window = window
    }

    func ensureRegistered(around page: Int, style: MushafStyle) async {
        guard let pack = style.pageFonts else { return }
        let current = registeredPages(style: style.id)
        let unavailable = state.withLock { $0.unavailable[style.id] ?? [] }
        let plan = window.plan(around: page, registered: current.union(unavailable), pages: style.pages)
        for number in plan.register {
            register(number, pack: pack, style: style.id)
        }
        for number in plan.unregister where current.contains(number) {
            unregister(number, pack: pack, style: style.id)
        }
    }

    func ensureRegistered(page: Int, style: MushafStyle) async {
        guard let pack = style.pageFonts, style.pages.contains(page), status(page: page, style: style.id) == .pending else { return }
        register(page, pack: pack, style: style.id)
    }

    nonisolated func status(page: Int, style: MushafStyleID) -> PageFontStatus {
        state.withLock { state in
            if state.registered[style]?.contains(page) == true { return .registered }
            if state.unavailable[style]?.contains(page) == true { return .unavailable }
            return .pending
        }
    }

    nonisolated func registeredPages(style: MushafStyleID) -> Set<Int> {
        state.withLock { $0.registered[style] ?? [] }
    }

    // MARK: Registration

    private func url(_ page: Int, pack: PageFontPack) -> URL? {
        guard let root else { return nil }
        let url = root.appendingPathComponent(pack.directory).appendingPathComponent(pack.fileName(page: page)).appendingPathExtension("ttf")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func register(_ page: Int, pack: PageFontPack, style: MushafStyleID) {
        let expected = pack.postScriptName(page: page)
        guard let url = url(page, pack: pack) else {
            return markUnavailable(page, style: style, "missing \(pack.directory)/\(pack.fileName(page: page)).ttf")
        }
        // The name inside the file, before registering it: a wrong file must never shadow another
        // page's font.
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
        let fileName = descriptors.first.flatMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
        guard fileName == expected else {
            return markUnavailable(page, style: style, "\(url.lastPathComponent) is \(fileName ?? "unreadable"), expected \(expected)")
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error),
           let cfError = error?.takeRetainedValue(),
           CFErrorGetCode(cfError) != CTFontManagerError.alreadyRegistered.rawValue {
            return markUnavailable(page, style: style, "could not register \(url.lastPathComponent): \(cfError)")
        }
        // CoreText substitutes silently for unknown names: check what the name resolves to.
        let resolved = CTFontCopyPostScriptName(CTFontCreateWithName(expected as CFString, 12, nil)) as String
        guard resolved == expected else {
            return markUnavailable(page, style: style, "\(expected) resolved to \(resolved)")
        }
        state.withLock { _ = $0.registered[style, default: []].insert(page) }
    }

    private func unregister(_ page: Int, pack: PageFontPack, style: MushafStyleID) {
        state.withLock { _ = $0.registered[style]?.remove(page) }
        guard let url = url(page, pack: pack) else { return }
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
    }

    private func markUnavailable(_ page: Int, style: MushafStyleID, _ reason: String) {
        state.withLock { _ = $0.unavailable[style, default: []].insert(page) }
        Self.logger.error("Page font unavailable, using the Unicode renderer: \(reason, privacy: .public)")
    }
}

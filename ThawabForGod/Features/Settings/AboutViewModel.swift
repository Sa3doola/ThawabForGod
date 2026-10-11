//
//  AboutViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// What the app is, and what it is built from.
@Observable
@MainActor
final class AboutViewModel {
    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private let quran: (any QuranRepositoring)?
    @ObservationIgnored private let packStore: (any ContentPackStoring)?

    /// - Parameters:
    ///   - bundle: where the version is read from. Injected so a test does not assert against
    ///     whatever the test host happens to be versioned as.
    ///   - quran: what this build's Quran database can draw. `nil` keeps the default list.
    ///   - packs: the translation and tafsir packs bundled in this build.
    init(
        bundle: Bundle = .main,
        quran: (any QuranRepositoring)? = nil,
        packs: (any ContentPackStoring)? = nil
    ) {
        self.bundle = bundle
        self.quran = quran
        self.packStore = packs
    }

    /// The marketing version, with the build behind it — `1.0 (12)`.
    ///
    /// Not routed through the digit formatter: a version is an identifier rather than a quantity,
    /// and `١.٠ (١٢)` would not match what the App Store, a crash report or a bug reporter says.
    var versionText: String {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = bundle.infoDictionary?["CFBundleVersion"] as? String else {
            return version
        }
        return "\(version) (\(build))"
    }

    /// Every bundled data set and dependency, for the attribution screen.
    /// Starts as the default list and changes once `loadQuranSources()` has asked the build what
    /// the Quran database carries.
    private(set) var sources: [AttributionSource] = AttributionSource.all

    /// The bundled translation, tafsir and surah-info packs, each with its own licence.
    private(set) var quranPacks: [ContentPack] = []

    /// Reads this build's capabilities and packs. The Mushaf data rows are listed only where the
    /// database carries Mushaf pages, never by the name of the file.
    func loadQuranSources() async {
        if let quran {
            let capabilities = (try? await quran.capabilities()) ?? []
            sources = AttributionSource.all(includingMushafData: capabilities.supportsMushafPages)
        }
        if let packStore {
            quranPacks = await packStore.installed()
        }
    }
}

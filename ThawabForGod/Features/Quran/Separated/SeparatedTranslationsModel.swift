import Foundation
import Observation

/// The translations drawn under each ayah in separated mode, for the one surah on screen.
///
/// Owned by `AppContainer` so a rebuilt list finds its surah already loaded. Only the list's body
/// reads it; rows are handed plain arrays, so scrolling observes nothing here.
@Observable @MainActor
final class SeparatedTranslationsModel {
    @ObservationIgnored private let repository: any TranslationRepositoring
    @ObservationIgnored private var installed: [ContentPack]?
    /// The surah the latest `load` asked for; a finished load applies only if it is still this one.
    @ObservationIgnored private var requestedSurah: Int?

    /// The surah whose load (on or off) has finished; nil before the first.
    private(set) var settledSurah: Int?
    @ObservationIgnored private var settledShown: Bool?
    /// The enabled list the settled load used (`nil`: every installed pack).
    @ObservationIgnored private var settledEnabled: [ContentPackID]?
    /// Parsed translations of `settledSurah`, per ayah, in pack order.
    private var byAyah: [VerseReference: [AyahPanelTranslation]] = [:]

    init(repository: any TranslationRepositoring) {
        self.repository = repository
    }

    /// In pack order; [] when off, none installed, still loading, or `ayah` is not in the loaded surah.
    func translations(for ayah: VerseReference) -> [AyahPanelTranslation] {
        guard ayah.surah == settledSurah else { return [] }
        return byAyah[ayah] ?? []
    }

    /// Latest call wins; checks `Task.isCancelled` and the asked surah before applying. Off: clears and settles.
    ///
    /// - Parameter enabled: the reader's enabled translations in order; `nil` is every installed one.
    func load(surah: Int, isShown: Bool, enabled: [ContentPackID]?) async {
        requestedSurah = surah
        // A rebuilt list finds its surah already loaded, so a restore does not wait on the database.
        if settledSurah == surah, settledShown == isShown, settledEnabled == enabled { return }
        guard isShown else {
            byAyah = [:]
            settledSurah = surah
            settledShown = false
            settledEnabled = enabled
            return
        }

        let installedPacks: [ContentPack]
        if let installed {
            installedPacks = installed
        } else {
            installedPacks = await repository.installed()
            installed = installedPacks
        }
        let packs = ContentPackSelection.enabledPacks(installed: installedPacks, enabled: enabled)

        // One query per pack; a pack that throws is skipped.
        var loaded: [(pack: ContentPack, texts: [VerseReference: TranslationText])] = []
        for pack in packs {
            if let texts = try? await repository.texts(surah: surah, pack: pack.id) {
                loaded.append((pack, texts))
            }
        }
        guard !Task.isCancelled, requestedSurah == surah else { return }

        let parsed = await Self.parse(loaded.map { ($0.pack, $0.texts) })
        guard !Task.isCancelled, requestedSurah == surah else { return }

        byAyah = parsed
        settledSurah = surah
        settledShown = true
        settledEnabled = enabled
    }

    /// Builds each ayah's documents off the main actor: up to 286 rows times every installed pack.
    @concurrent
    nonisolated private static func parse(
        _ packs: [(ContentPack, [VerseReference: TranslationText])]
    ) async -> [VerseReference: [AyahPanelTranslation]] {
        var result: [VerseReference: [AyahPanelTranslation]] = [:]
        for (pack, texts) in packs {
            for (reference, text) in texts {
                result[reference, default: []].append(
                    AyahPanelTranslation(pack: pack, document: TranslationDocument(text))
                )
            }
        }
        return result
    }
}

//
//  AyahPanelViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// The two sections of the ayah panel.
nonisolated enum AyahPanelSection: String, CaseIterable, Identifiable, Sendable {
    case translation, tafsir

    var id: String { rawValue }
}

/// One translation of the panel's ayah, parsed.
nonisolated struct AyahPanelTranslation: Identifiable, Equatable, Sendable {
    let pack: ContentPack
    let document: TranslationDocument

    var id: ContentPackID { pack.id }
}

/// The tafsir entry for the panel's ayah and its parsed text.
nonisolated struct AyahPanelTafsir: Equatable, Sendable {
    let entry: TafsirEntry
    let pack: ContentPack
    let document: TafsirDocument
}

/// Silence and failure are two phases (T16): a commentary that passes over an ayah is not one
/// that could not be read, and a neighbour's note is never shown in either case.
nonisolated enum AyahPanelTafsirPhase: Equatable, Sendable {
    case idle
    case loaded(AyahPanelTafsir)
    /// The commentary has no note on this ayah.
    case silent(ContentPack)
    case unavailable
}

/// The ayah panel's content. One per section, owned by `AppContainer`; the picked tafsir and the
/// requested section live for the session and are not persisted (M5.6 adds defaults).
@Observable @MainActor
final class AyahPanelViewModel {
    private let translationRepository: any TranslationRepositoring
    private let tafsirRepository: any TafsirRepositoring

    private(set) var translationPacks: [ContentPack] = []
    private(set) var tafsirPacks: [ContentPack] = []
    private(set) var translations: [AyahPanelTranslation] = []
    /// The ayah `translations` belongs to. Observed, so a view that asks `translations(for:)` redraws
    /// when the text for its ayah lands.
    private(set) var translationsAyah: VerseReference?
    private(set) var tafsir: AyahPanelTafsirPhase = .idle

    var requestedSection: AyahPanelSection = .translation
    var pickedTafsir: ContentPackID?

    @ObservationIgnored private var packsLoaded = false
    /// The ayah and tafsir the latest `load` asked for: a result is applied only if these still match.
    @ObservationIgnored private var askedAyah: VerseReference?
    @ObservationIgnored private var askedTafsir: ContentPackID?

    init(translations: any TranslationRepositoring, tafsir: any TafsirRepositoring) {
        self.translationRepository = translations
        self.tafsirRepository = tafsir
    }

    /// The translations of `ayah`, or none while another ayah's are still on hand: text is never
    /// paired with a neighbour's Arabic, on screen or in Copy.
    func translations(for ayah: VerseReference) -> [AyahPanelTranslation] {
        translationsAyah == ayah ? translations : []
    }

    // MARK: Sections

    /// Every installed tafsir until M5.6 adds the enabled list.
    func enabledTafsirs() -> [ContentPack] {
        TafsirChoice.enabled(installed: tafsirPacks, enabled: nil)
    }

    func currentTafsir(language: AppLanguage) -> ContentPack? {
        TafsirChoice.current(
            enabled: enabledTafsirs(), picked: pickedTafsir, defaultTafsir: nil, appLanguage: language.rawValue)
    }

    /// Translation only if a translation pack is installed; Tafsir only if there is a tafsir.
    func sections(language: AppLanguage) -> [AyahPanelSection] {
        var result: [AyahPanelSection] = []
        if !translationPacks.isEmpty { result.append(.translation) }
        if currentTafsir(language: language) != nil { result.append(.tafsir) }
        return result
    }

    /// The requested section if it exists, else the first one that does; nil when there are none.
    func shownSection(language: AppLanguage) -> AyahPanelSection? {
        let available = sections(language: language)
        return available.contains(requestedSection) ? requestedSection : available.first
    }

    // MARK: Loading

    /// Packs once, then the translations, then the tafsir. Idempotent: asking again for what is
    /// already shown does no work.
    func load(ayah: VerseReference, language: AppLanguage) async {
        askedAyah = ayah
        if !packsLoaded {
            let translationPacks = await translationRepository.installed()
            let tafsirPacks = await tafsirRepository.installed()
            self.translationPacks = translationPacks
            self.tafsirPacks = tafsirPacks
            packsLoaded = true
        }
        guard askedAyah == ayah else { return }
        await loadTranslations(ayah: ayah)
        guard askedAyah == ayah else { return }
        await loadTafsir(ayah: ayah, language: language)
    }

    private func loadTranslations(ayah: VerseReference) async {
        guard translationsAyah != ayah else { return }
        guard !translationPacks.isEmpty else {
            translations = []
            translationsAyah = ayah
            return
        }
        let packs = translationPacks
        do {
            let texts = try await translationRepository.text(for: ayah, packs: packs.map(\.id))
            guard askedAyah == ayah else { return }
            translations = texts.compactMap { text in
                packs.first { $0.id == text.pack }.map { AyahPanelTranslation(pack: $0, document: TranslationDocument(text)) }
            }
            translationsAyah = ayah
        } catch {
            guard askedAyah == ayah else { return }
            translations = []
        }
    }

    private func loadTafsir(ayah: VerseReference, language: AppLanguage) async {
        guard let pack = currentTafsir(language: language) else {
            tafsir = .idle
            askedTafsir = nil
            return
        }
        askedTafsir = pack.id
        if case .loaded(let loaded) = tafsir, loaded.pack.id == pack.id, loaded.entry.range.contains(ayah) { return }
        // A neighbour's note is never left under this ayah while the new one loads.
        tafsir = .idle
        do {
            let entry = try await tafsirRepository.tafsir(for: ayah, pack: pack.id)
            guard askedAyah == ayah, askedTafsir == pack.id else { return }
            guard let entry else {
                tafsir = .silent(pack)
                return
            }
            let document = await TafsirDocument.parsed(html: entry.html)
            guard askedAyah == ayah, askedTafsir == pack.id else { return }
            tafsir = .loaded(AyahPanelTafsir(entry: entry, pack: pack, document: document))
        } catch {
            guard askedAyah == ayah, askedTafsir == pack.id else { return }
            tafsir = .unavailable
        }
    }
}

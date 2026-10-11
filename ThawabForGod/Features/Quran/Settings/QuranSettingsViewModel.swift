//
//  QuranSettingsViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// What the Quran settings form edits: the reader's preferences, plus the two pack lists whose rows
/// come from the bundled packs rather than from a preference.
///
/// One instance serves both doors to the form (Settings → Quran, and the reader's sheet), owned by
/// `AppContainer`. Every choice goes through `QuranReaderSettings`, which writes its own key; a key
/// is written only by a control's setter, so opening the screen writes nothing.
@Observable
@MainActor
final class QuranSettingsViewModel {
    let settings: QuranReaderSettings

    /// `nil` until `load()` has read the installed packs.
    private(set) var translationSelection: ContentPackSelection?
    private(set) var tafsirSelection: ContentPackSelection?

    @ObservationIgnored private let reader: QuranReaderViewModel
    @ObservationIgnored private let translations: any TranslationRepositoring
    @ObservationIgnored private let tafsir: any TafsirRepositoring
    /// The packs in store order, which a selection's own rows are not (enabled ones come first).
    @ObservationIgnored private var installedTranslations: [ContentPack] = []
    @ObservationIgnored private var installedTafsirs: [ContentPack] = []

    init(
        settings: QuranReaderSettings,
        reader: QuranReaderViewModel,
        translations: any TranslationRepositoring,
        tafsir: any TafsirRepositoring
    ) {
        self.settings = settings
        self.reader = reader
        self.translations = translations
        self.tafsir = tafsir
    }

    /// Loads the corpus capabilities (so the Mushaf rows exist before the Quran tab was opened) and
    /// the installed packs. Writes nothing.
    func load() async {
        await reader.load()
        installedTranslations = await translations.installed()
        installedTafsirs = await tafsir.installed()
        rebuildSelections()
    }

    // MARK: Display

    /// Through the reader, so switching keeps the reader's place.
    func setDisplayMode(_ mode: QuranDisplayMode) {
        reader.setDisplayMode(mode)
    }

    // MARK: Packs

    func setTranslation(_ id: ContentPackID, enabled: Bool) {
        update(&translationSelection) { $0.setEnabled(enabled, for: id) }
        store(translationSelection) { settings.setEnabledTranslations($0) }
    }

    func moveTranslations(fromOffsets source: IndexSet, toOffset destination: Int) {
        update(&translationSelection) { $0.move(fromOffsets: source, toOffset: destination) }
        store(translationSelection) { settings.setEnabledTranslations($0) }
    }

    func setTafsir(_ id: ContentPackID, enabled: Bool) {
        update(&tafsirSelection) { $0.setEnabled(enabled, for: id) }
        store(tafsirSelection) { settings.setEnabledTafsirs($0) }
    }

    func moveTafsirs(fromOffsets source: IndexSet, toOffset destination: Int) {
        update(&tafsirSelection) { $0.move(fromOffsets: source, toOffset: destination) }
        store(tafsirSelection) { settings.setEnabledTafsirs($0) }
    }

    /// The stored default, only while it is enabled. A stored default that has since been disabled
    /// reads as Automatic here, and the key is left alone.
    var defaultTafsir: ContentPackID? {
        guard let id = settings.defaultTafsir, tafsirSelection?.enabled.contains(id) == true else { return nil }
        return id
    }

    /// `nil` is Automatic and deletes the key.
    func setDefaultTafsir(_ id: ContentPackID?) {
        settings.setDefaultTafsir(id)
    }

    /// Back to "no preference": the reader's keys are deleted, and the lists read "all installed".
    func reset() {
        settings.reset()
        rebuildSelections()
    }

    // MARK: Private

    private func rebuildSelections() {
        translationSelection = ContentPackSelection(installed: installedTranslations, enabled: settings.enabledTranslations)
        tafsirSelection = ContentPackSelection(installed: installedTafsirs, enabled: settings.enabledTafsirs)
    }

    private func update(_ selection: inout ContentPackSelection?, _ change: (inout ContentPackSelection) -> Void) {
        guard var current = selection else { return }
        change(&current)
        selection = current
    }

    private func store(_ selection: ContentPackSelection?, _ write: ([ContentPackID]) -> Void) {
        guard let selection else { return }
        write(selection.enabled)
    }
}

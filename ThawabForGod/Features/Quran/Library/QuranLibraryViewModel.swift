//
//  QuranLibraryViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Where "Continue reading" returns to.
nonisolated struct QuranLibraryResume: Equatable, Sendable {
    let surah: Surah
    let ayah: VerseReference
    /// `nil` in a build without the printed pages.
    let page: Int?
}

/// The Library's session: the index built from the reader's corpus, the selected tab, and the
/// field's text with what it filters.
///
/// One instance for the section, owned by `AppContainer` and built before any view, so the tab, the
/// text typed so far and the error survive an iPad crossing compact and regular (docs/quran-migration/
/// design/M5.2.md, 3.1). **It writes no setting.** The tab changes without the reader choosing it
/// (typing a name moves to Surah), so a stored tab would break "only write a key the user chose".
///
/// **Everything the four indexes show is built once**, from the corpus the reader already loaded;
/// a keystroke only folds the query and filters 114 rows held in memory.
@Observable
@MainActor
final class QuranLibraryViewModel {
    nonisolated enum Phase: Sendable {
        case loading
        case failed
        case ready(QuranLibraryIndex)
    }

    @ObservationIgnored private let reader: QuranReaderViewModel
    @ObservationIgnored private let surahInfo: SurahInfoViewModel

    private var index: QuranLibraryIndex?
    /// What was asked for, which may be a tab this build does not have: `tab` judges it.
    private var requestedTab: QuranLibraryTab = .surah

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            failure = nil
            refilter()
            // A name moves to Surah, where it filters; a number or an address never moves the tab.
            if case .name = input { requestedTab = .surah }
        }
    }

    private(set) var filteredSurahs: [QuranLibrarySurahRow] = []
    private(set) var failure: QuranGoToFailure?

    @ObservationIgnored private let userData: QuranUserDataStore?

    init(reader: QuranReaderViewModel, surahInfo: SurahInfoViewModel, userData: QuranUserDataStore? = nil) {
        self.reader = reader
        self.surahInfo = surahInfo
        self.userData = userData
    }

    // MARK: Derived

    /// The reader's load, and then the index built from its corpus.
    var phase: Phase {
        switch reader.phase {
        case .loading: .loading
        case .failed: .failed
        case .ready: index.map(Phase.ready) ?? .loading
        }
    }

    /// The requested tab if this build has it, else Surah. A request made before the corpus loaded
    /// (a launch option) is judged once it has.
    var tab: QuranLibraryTab {
        get { visibleTabs.contains(requestedTab) ? requestedTab : .surah }
        set { requestedTab = newValue }
    }

    var visibleTabs: [QuranLibraryTab] {
        index?.tabs ?? QuranLibraryIndex.tabs(showingPages: false)
    }

    var showsPages: Bool { index?.showsPages ?? false }

    /// What the field's text is, classified in this one place and knowing the surah names, so a
    /// name that is also an address in progress (ص) is a name.
    private var input: QuranGoToInput {
        QuranGoTo.input(query, among: index?.surahs ?? [])
    }

    var isFilteringSurahs: Bool {
        switch input {
        case .number, .name: true
        case .empty, .address: false
        }
    }

    var canSubmit: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The trimmed field text when it is Arabic words the text search can take; nil otherwise. A
    /// name in Latin letters, a number or an address is the go-to's, not the search's.
    var textSearchSuggestion: String? {
        guard case .name = input else { return nil }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasArabic = text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
        guard hasArabic, QuranSearchQuery(text, scope: .quran) != nil else { return nil }
        return text
    }

    var hasSurahInfo: Bool { surahInfo.isAvailable }

    /// The reader's place right now. Reads state the reader changes on every page turn, so a `body`
    /// may read it only while `QuranCoordinator.canContinueReading` is true (design note, 3.5).
    var resume: QuranLibraryResume? {
        guard let corpus = reader.corpus else { return nil }
        guard reader.hasLivePlace else {
            // Nothing has been opened in this process: the stored position, if it still names a verse.
            guard let ayah = userData?.readingPosition?.ayah,
                  corpus.ayah(ayah) != nil, let surah = corpus.surah(ayah.surah) else { return nil }
            return QuranLibraryResume(
                surah: surah, ayah: ayah, page: showsPages ? corpus.pageNumber(for: ayah) : nil)
        }
        let location = reader.location
        guard let surah = corpus.surah(location.surah) else { return nil }
        // The page gate is the index's, through `showsPages`. Before the index exists it is false,
        // so a `resume` asked that early has no page, and a build without pages never gets one.
        let page: Int?
        if !showsPages {
            page = nil
        } else if reader.showsMushafPages {
            // The page on screen, not the page of the ayah: that ayah may have started on the one before.
            page = reader.mushaf.page
        } else {
            page = corpus.pageNumber(for: location)
        }
        return QuranLibraryResume(surah: surah, ayah: location, page: page)
    }

    // MARK: Load

    /// Every step is idempotent, so two callers at once (the stack's task and the root's) are safe.
    /// It never checks `Task.isCancelled` after an `await`: a cancelled caller must still leave the
    /// index in place, and nothing here is cancelled or detached beyond the one `@concurrent` hop.
    func load(language: AppLanguage) async {
        await reader.load()
        guard let corpus = reader.corpus, index == nil else { return }
        // Before the index is published, so the first frame that has rows knows whether a row
        // offers surah info.
        await surahInfo.prepare(language: language)
        // `make(from:)` is `@concurrent`: awaiting it leaves the main actor for the folding and the
        // grouping, the way the repository's methods do, and returns one `Sendable` value.
        let built = await QuranLibraryIndex.make(from: corpus)
        if index == nil {
            index = built
            refilter()
        }
    }

    func retry(language: AppLanguage) async {
        await reader.retry()
        await load(language: language)
    }

    // MARK: Field

    /// Submits the field. A target: the field is cleared, open it. `nil`: `failure` says why.
    func submit() -> GoToTarget? {
        guard canSubmit, let corpus = reader.corpus, let index else { return nil }
        switch QuranGoTo.resolve(query, corpus: corpus, index: index) {
        case .go(let target):
            query = ""
            return target
        case .failed(let reason):
            failure = reason
            return nil
        }
    }

    /// The Library opened something: the field is cleared, as Mushaf's sheet was dismissed.
    func didOpen() {
        query = ""
    }

    private func refilter() {
        filteredSurahs = QuranGoTo.surahs(index?.surahs ?? [], matching: query)
    }
}

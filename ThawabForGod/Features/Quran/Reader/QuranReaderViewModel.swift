//
//  QuranReaderViewModel.swift
//  ThawabForGod
//

import Observation

/// The Quran reader's session: the corpus load, where the reader is in either mode, and the switch
/// between the modes that keeps that place.
///
/// Mushaf's `ReaderModel` with the khatmah, the restored windows and the shared singleton taken out
/// (docs/quran-migration/design/M5.1.md, sections 3.2 and 3.3). One instance for the whole section,
/// owned by `AppContainer`, so the corpus loads once and the place survives the view tree being
/// rebuilt.
///
/// **What changes on every scroll or page turn is not observed here.** The Mushaf page and the
/// selection live on `MushafReadingState`, which only the pager and its pages read; the first ayah
/// in view in separated mode is `@ObservationIgnored`. Neither may invalidate the reader screen
/// above the list, which is the one measured way this reader gets slower (design note, 3.4).
@Observable
@MainActor
final class QuranReaderViewModel {
    nonisolated enum Phase: Sendable {
        case loading
        case ready(QuranCorpus)
        case failed
    }

    private(set) var phase: Phase = .loading
    let settings: QuranReaderSettings
    /// The pager's page, the selection and the chrome request. One for the session.
    let mushaf: MushafReadingState
    /// The surah separated mode shows. Changes on navigation only.
    private(set) var separatedSurah = 1
    /// A jump inside the surah on screen.
    private(set) var separatedScrollRequest: SeparatedScrollRequest?
    /// The first ayah in view in separated mode. Written on every top-ayah change and read in a
    /// `body` in exactly one place, when a list is created, where the value current at that moment
    /// is the one wanted. Observing it would re-evaluate the reader, its surface and the list for
    /// every ayah scrolled past.
    @ObservationIgnored private(set) var separatedLocation = VerseReference(surah: 1, verse: 1)

    @ObservationIgnored private let repository: any QuranRepositoring
    @ObservationIgnored private let style: MushafStyle
    @ObservationIgnored private let allowsImmersive: Bool
    /// A target that arrived before the corpus did. The latest wins.
    @ObservationIgnored private var parkedTarget: GoToTarget?
    @ObservationIgnored private var scrollSerial = 0
    /// The one read the whole section needs, shared by every caller of `load()`. It belongs to the
    /// session rather than to the view whose `.task` asked: a load tied to that task would end with
    /// the view, and a reader popped or a tab switched half a second in would be left with a failed
    /// phase they did nothing to earn. So it is stored, and never cancelled.
    @ObservationIgnored private var loadTask: Task<(QuranCapabilities, QuranCorpus), Error>?

    init(
        repository: any QuranRepositoring,
        settings: QuranReaderSettings,
        style: MushafStyle = .madaniV2,
        allowsImmersive: Bool? = nil
    ) {
        self.repository = repository
        self.settings = settings
        self.style = style
        // `nil` means "ask the device". The question is asked here and not in the default argument
        // because a default value is evaluated outside the main actor, where `DeviceKind.isPhone`
        // cannot be read.
        self.allowsImmersive = allowsImmersive ?? DeviceKind.isPhone
        mushaf = MushafReadingState(page: 1, pages: style.pages)
    }

    // MARK: Derived

    var corpus: QuranCorpus? {
        if case .ready(let corpus) = phase { corpus } else { nil }
    }

    /// Whether Mushaf pages are what is on screen: the condition `QuranReadingSurface` switches on,
    /// so the two cannot disagree.
    var showsMushafPages: Bool {
        settings.displayMode == .mushaf && (corpus?.hasPages ?? false)
    }

    /// Whether the mode toggle exists: only a build with more than one mode to offer.
    var canSwitchDisplayMode: Bool {
        settings.availableDisplayModes.count > 1
    }

    /// The first ayah in view, whichever mode is showing. Never read this in a `body`.
    var location: VerseReference {
        if showsMushafPages, let first = corpus?.page(mushaf.page)?.firstAyah { return first }
        return separatedLocation
    }

    // MARK: Load

    func load() async {
        if case .ready = phase { return }
        let task = loadTask ?? makeLoadTask()
        loadTask = task
        do {
            let (capabilities, corpus) = try await task.value
            // Two callers await one task; whichever resumes first applies the result.
            if case .ready = phase { return }
            // The one place the build's capabilities reach the settings.
            settings.apply(capabilities)
            phase = .ready(corpus)
            if let target = parkedTarget {
                parkedTarget = nil
                open(target)
            }
        } catch {
            guard loadTask == task else { return }
            loadTask = nil
            phase = .failed
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    private func makeLoadTask() -> Task<(QuranCapabilities, QuranCorpus), Error> {
        // Inherits the main actor; the repository's `@concurrent` methods are what leave it.
        Task { [repository, style] in
            let capabilities = try await repository.capabilities()
            let corpus = try await repository.loadCorpus(style: style.id)
            return (capabilities, corpus)
        }
    }

    // MARK: Navigation

    /// Opens at a target in both modes at once, now if the corpus is loaded and else once it is.
    /// A target the corpus does not contain changes nothing.
    func open(_ target: GoToTarget) {
        guard let corpus else {
            parkedTarget = target
            return
        }
        guard let place = QuranReaderPlace.resolve(target, in: corpus) else { return }
        if place.selectsAyah { mushaf.select(place.ayah) }
        if let page = place.page { mushaf.show(page: page) }
        // Before the surah: the surah is what re-evaluates the view that reads the location.
        separatedLocation = place.ayah
        if separatedSurah == place.ayah.surah {
            scrollSerial += 1
            separatedScrollRequest = SeparatedScrollRequest(ayah: place.ayah, serial: scrollSerial)
        } else {
            separatedSurah = place.ayah.surah
        }
    }

    /// A tap on an ayah: selects it. Never clears: the panel the tap opens is closed from the panel,
    /// and the selection stays after it closes, as in Mushaf.
    func select(_ ayah: VerseReference) {
        mushaf.select(ayah)
        // Read from there, as Mushaf does.
        if !showsMushafPages { separatedLocation = ayah }
    }

    /// Switches modes keeping the reader's place, and writes nothing but the mode:
    /// separated to Mushaf opens the page holding the first ayah in view; Mushaf to separated opens
    /// the first ayah of the page on screen. The place is set before the mode, so the new reader is
    /// built already positioned.
    func setDisplayMode(_ mode: QuranDisplayMode) {
        guard settings.availableDisplayModes.contains(mode), mode != settings.displayMode else { return }
        if let corpus {
            switch mode {
            case .mushaf:
                if let page = corpus.pageNumber(for: separatedLocation) { mushaf.show(page: page) }
            case .separated:
                if let first = corpus.page(mushaf.page)?.firstAyah {
                    separatedLocation = first
                    separatedSurah = first.surah
                }
                mushaf.isChromeHidden = false
            }
        }
        settings.select(displayMode: mode)
    }

    func toggleDisplayMode() {
        setDisplayMode(settings.displayMode == .mushaf ? .separated : .mushaf)
    }

    /// The separated list reports its first ayah in view. Goes into an unobserved property.
    func separatedTopAyahDidChange(_ ayah: VerseReference) {
        separatedLocation = ayah
    }

    // MARK: Immersive

    /// Whether the bars should be hidden: the chrome request, honoured only where the device allows
    /// it, while pages are showing, and never while VoiceOver is running.
    func isImmersive(voiceOverRunning: Bool) -> Bool {
        allowsImmersive && mushaf.isChromeHidden && showsMushafPages && !voiceOverRunning
    }

    /// Clears the request so the bars do not hide again on their own later.
    func exitImmersive() {
        mushaf.isChromeHidden = false
    }
}

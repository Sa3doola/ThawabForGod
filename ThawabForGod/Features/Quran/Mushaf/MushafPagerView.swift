//
//  MushafPagerView.swift
//  ThawabForGod
//

import SwiftUI

extension EnvironmentValues {
    /// True while the ayah panel holds one half of a vertically folded display: the pager then is the
    /// other half and ignores the fold, like `ignoresFold`. Read by the pager; set by the ayah side panel's presentation modifier.
    @Entry var mushafPanelCoversFold: Bool = false
}

/// Shows or hides the reader's chrome (iPhone immersive reading). Set on the pager's row only
/// while that applies; `nil` elsewhere, where a tap outside the text does nothing.
struct MushafChromeToggle {
    let toggle: () -> Void

    /// iPhone immersive reading: a tap outside the text shows or hides the chrome. Off with
    /// VoiceOver (it pages with its own gestures), and on iPad and the Mac. Set once for the
    /// pager, not per unit: the same closure for every page, in either page-turn mode.
    static func pager(state: MushafReadingState, voiceOverEnabled: Bool, reduceMotion: Bool) -> MushafChromeToggle? {
        guard DeviceKind.isPhone, !voiceOverEnabled else { return nil }
        return MushafChromeToggle(
            // Reduce Motion: the bars appear and go without sliding.
            toggle: { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { state.isChromeHidden.toggle() } }
        )
    }
}

extension EnvironmentValues {
    @Entry var mushafChromeToggle: MushafChromeToggle?
}

/// The style's pages as a horizontal book, always right-to-left: page 1 is the rightmost page and
/// the next page lies to the left, as in a printed Arabic Mushaf.
///
/// Ported from Mushaf. `MushafPageUnit` decides what one screen holds: a single page, a spread of
/// facing pages (iPad landscape, a foldable's inner display: odd page on the right, 1|2, 3|4, …),
/// or on an iPhone in landscape one page fitted to the width that scrolls vertically. **The size it
/// decides from is this view's own** — the tab's, or the split view's detail column — never the
/// window's (T11).
///
/// When the pager settles on a page it registers that page's font window (±3, dropping fonts more
/// than 20 pages away) and measures the neighbours off the main actor, so a page turn or a jump
/// finds them ready and draws in one pass.
struct MushafPagerView: View {
    let corpus: QuranCorpus
    let state: MushafReadingState
    let settings: QuranReaderSettings
    let services: MushafRenderServices
    /// The ayah panel sits beside the pager (M5): the pager is one half of the display, so a fold is
    /// at its edge rather than between two pages, and it shows one page.
    var ignoresFold = false
    /// The top half of a horizontally folded display (tabletop, M7): short and wide, so one page
    /// fitted to the width, as on an iPhone in landscape.
    var isTabletop = false
    /// The highlights and bookmarks of the pages, from the reader's user data (M6).
    var marks: QuranAyahMarks = .none
    let onSelect: (VerseReference) -> Void

    /// The widest a tabletop page gets: the whole width of the inner display would make the text
    /// ~40 pt and leave two lines in view; 600 pt gives ~27 pt and about five lines.
    static let tabletopPageWidth: CGFloat = 600

    @Environment(\.readingPalette) private var palette
    @Environment(\.quranFaces) private var faces
    @Environment(\.forcedRenderer) private var forcedRenderer
    @Environment(\.foldOverride) private var foldOverride
    @Environment(\.mushafPanelCoversFold) private var panelCoversFold
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(LocalizationManager.self) private var l10n
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    /// First page of the unit (page or spread) currently snapped into view.
    @State private var visibleUnit: Int?
    /// A programmatic jump still settling: the scroll view's reports of other units are stale until
    /// it arrives (two quick page turns must not undo each other).
    @State private var jumpTarget: Int?

    var body: some View {
        GeometryReader { geometry in
            let fold = (ignoresFold || panelCoversFold) ? nil : FoldGeometry.resolve(in: geometry, override: foldOverride)
            let unit = unit(for: geometry.size, fold: fold)
            // Side insets can be asymmetric (a foldable's vertical system bar), and a paging scroll
            // view must be exactly one screen wide or the next page peeks in. So the scroll view
            // ignores the horizontal safe area and each unit applies the insets once. The size
            // decision above uses the safe-area size.
            let sideInsets = EdgeInsets(top: 0, leading: geometry.safeAreaInsets.leading, bottom: 0, trailing: geometry.safeAreaInsets.trailing)
            // Book turning only where the platform has it, the reader chose it, and nothing asks for
            // less motion or a different gesture. A page fitted to the width scrolls vertically,
            // which fights the curl's pan, so it slides.
            let usesCurl = MushafPagerPlatform.supportsCurl && settings.pageTurn == .curl
                && !reduceMotion && !voiceOverEnabled && unit != .widthFit
            Group {
                if usesCurl {
                    curlPager(unit: unit, fold: fold, sideInsets: sideInsets, width: geometry.size.width)
                        // As the Slide pager: the pages pad their own outer edge, so the safe area must not too.
                        .ignoresSafeArea(.container, edges: .horizontal)
                } else {
                    slidePager(unit: unit, fold: fold, sideInsets: sideInsets)
                }
            }
            .environment(\.mushafChromeToggle, MushafChromeToggle.pager(state: state, voiceOverEnabled: voiceOverEnabled, reduceMotion: reduceMotion))
            // Shared by both modes: the unit's size for the view model, and the font window.
            .onChange(of: unit.pageCount, initial: true) { _, count in
                state.visiblePageCount = count
            }
            .task(id: state.page) {
                await prepare(around: state.page)
            }
            .onChange(of: state.page) { _, page in
                guard voiceOverEnabled else { return }
                AccessibilityNotification.Announcement(l10n.string(.quranPageNumber, l10n.string(page, grouped: false))).post()
            }
        }
        // Paper behind the system bars too (the background extends into the safe areas).
        .background(palette.background)
        // Forced whatever the interface language: a Mushaf always pages right-to-left.
        .environment(\.layoutDirection, .rightToLeft)
    }

    /// The book: a page curl. With a fold the curl is framed so its spine (its centre) is on the hinge.
    @ViewBuilder
    private func curlPager(unit: MushafPageUnit, fold: FoldGeometry?, sideInsets: EdgeInsets, width: CGFloat) -> some View {
        let pager = MushafCurlPager(
            corpus: corpus, state: state, settings: settings, services: services, unit: unit,
            fold: fold, sideInsets: sideInsets, marks: marks, onSelect: onSelect
        )
        // The spine is fixed when the controller is built, so a new unit builds a new one.
        .id(unit)
        if let fold, unit == .spread {
            let curlWidth = 2 * min(fold.leadingWidth, fold.trailingWidth) + fold.gutterWidth
            // The layout is right-to-left, so the leading side is on the right; offsets are physical.
            pager
                .frame(width: curlWidth)
                .offset(x: (fold.trailingWidth - fold.leadingWidth) / 2)
                .frame(maxWidth: .infinity)
        } else {
            pager
        }
    }

    /// Today's pager, unchanged: a paging horizontal scroll view of units.
    private func slidePager(unit: MushafPageUnit, fold: FoldGeometry?, sideInsets: EdgeInsets) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                MushafPagerUnits(
                    corpus: corpus,
                    state: state,
                    settings: settings,
                    services: services,
                    unit: unit,
                    fold: fold,
                    sideInsets: sideInsets,
                    maxPageWidth: isTabletop ? Self.tabletopPageWidth : nil,
                    marks: marks,
                    onSelect: onSelect
                )
            }
            .ignoresSafeArea(.container, edges: .horizontal)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $visibleUnit)
            .scrollIndicators(.hidden)
            .task(id: unit) {
                // The initial jump, and re-anchoring when the layout switches between one page
                // and spreads (rotation, folding): stay on the same page.
                await Task.yield()
                let target = unit.unitStart(for: state.page)
                proxy.scrollTo(target)
                visibleUnit = target
            }
            .onChange(of: visibleUnit) { _, first in
                guard let first else { return }
                // A jump is settling: reports of other units are stale until it arrives.
                if let jumpTarget, first != jumpTarget { return }
                // A paging swipe moves one unit. Anything further is the RTL scroll view
                // reporting its mirrored origin: go back to where the reader is.
                guard MushafPagerStep.accepts(reported: first, page: state.page, pageCount: unit.pageCount, jumpTarget: jumpTarget) else {
                    jump(to: unit.unitStart(for: state.page), proxy: proxy, farJump: true)
                    return
                }
                // Keep the exact page if it is still visible (the left page of a spread).
                if !(first...(first + unit.pageCount - 1)).contains(state.page) { state.show(page: first) }
            }
            .onChange(of: state.page) { _, page in
                // Programmatic navigation (go to, a turn from a key or the menu).
                let target = unit.unitStart(for: page)
                guard target != visibleUnit else { return }
                let isNeighbour = visibleUnit.map { abs(target - $0) == unit.pageCount } ?? false
                jump(to: target, proxy: proxy, farJump: !isNeighbour)
            }
        }
    }

    /// Moves the scroll view to the unit starting at `target`. A neighbouring unit needs only the
    /// scroll position (one scroll path); a far one also asks the reader to scroll it into the lazy
    /// stack (a long jump back on the Mac otherwise stayed where it was). Once the window closes,
    /// a view that is still elsewhere is sent there once more.
    private func jump(to target: Int, proxy: ScrollViewProxy, farJump: Bool) {
        jumpTarget = target
        if farJump {
            proxy.scrollTo(target)
            visibleUnit = target
        } else {
            withAnimation(reduceMotion ? nil : .default) { visibleUnit = target }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard jumpTarget == target else { return }
            jumpTarget = nil
            if visibleUnit != target { proxy.scrollTo(target) }
        }
    }

    /// Registers the page fonts around `page`, then measures the neighbours, nearest first.
    private func prepare(around page: Int) async {
        await services.pageFonts.ensureRegistered(around: page, style: corpus.style)
        for offset in [0, 1, -1, 2, -2, 3, -3] {
            guard !Task.isCancelled, let neighbour = corpus.page(page + offset) else { continue }
            let renderer = await PageRenderer.resolve(
                style: corpus.style, page: neighbour.number, forced: forcedRenderer, store: services.pageFonts
            )
            _ = await services.metricsCache.measurement(
                for: neighbour, style: corpus.style.id, basmala: corpus.basmala, faces: faces, renderer: renderer
            )
        }
    }

    private func unit(for size: CGSize, fold: FoldGeometry?) -> MushafPageUnit {
        if isTabletop { return .widthFit }
        #if os(iOS)
        let isCompactWidth = horizontalSizeClass == .compact
        let isCompactHeight = verticalSizeClass == .compact
        #else
        let (isCompactWidth, isCompactHeight) = (false, false)
        #endif
        return MushafPageUnit.resolve(
            size: size,
            fold: fold?.kind,
            isCompactWidth: isCompactWidth,
            isCompactHeight: isCompactHeight,
            phoneLandscape: settings.phoneLandscape,
            flatOpen: settings.flatOpen,
            spreadFit: MushafSpreadFit(
                pageAspectRatio: corpus.style.pageAspectRatio,
                linesPerPage: corpus.style.linesPerPage,
                slotHeightEm: RendererMetrics.glyphPerPage.slotHeightEm
            )
        )
    }
}

/// The pager's row of units. A view of its own, with inputs that a page turn does not change: the
/// pager observes the current page (font registration, jumps), and when the row lived in its body
/// every page turn rebuilt the `ForEach` over all units and each unit's tap closures (Mushaf 8.2:
/// paging 1→604 took 49 s instead of 37 s, the main thread busy throughout).
private struct MushafPagerUnits: View {
    let corpus: QuranCorpus
    let state: MushafReadingState
    let settings: QuranReaderSettings
    let services: MushafRenderServices
    let unit: MushafPageUnit
    let fold: FoldGeometry?
    let sideInsets: EdgeInsets
    let maxPageWidth: CGFloat?
    let marks: QuranAyahMarks
    let onSelect: (VerseReference) -> Void

    var body: some View {
        LazyHStack(spacing: 0) {
            ForEach(Array(stride(from: corpus.style.pages.lowerBound, through: corpus.style.pageCount, by: unit.pageCount)), id: \.self) { first in
                MushafUnitView(
                    corpus: corpus, state: state, settings: settings, services: services, firstPage: first, unit: unit,
                    fold: fold, maxPageWidth: maxPageWidth, marks: marks, onSelect: onSelect
                )
                .padding(sideInsets)
                .containerRelativeFrame(.horizontal)
                .id(first)
            }
        }
        .scrollTargetLayout()
    }
}

/// One screen of the pager: a single page, a spread of two facing pages, or one page fitted to the
/// width in a vertical scroll view.
struct MushafUnitView: View {
    let corpus: QuranCorpus
    let state: MushafReadingState
    let settings: QuranReaderSettings
    let services: MushafRenderServices
    let firstPage: Int
    let unit: MushafPageUnit
    /// Vertical fold to place the gutter over; `nil` splits the width evenly.
    var fold: FoldGeometry?
    /// `.widthFit`: the page is never wider than this (tabletop); `nil` fills the width.
    var maxPageWidth: CGFloat?
    var marks: QuranAyahMarks = .none
    let onSelect: (VerseReference) -> Void

    /// Each page fits its own widest line; facing pages share the smaller size.
    @State private var sharedFontSize: CGFloat = .infinity

    @Environment(\.mushafChromeToggle) private var chromeToggle

    var body: some View {
        // The marks are read here, at the top level of this leaf's body, so this view observes the
        // store; the pages below get plain values. Nothing is read inside the lazy or geometry
        // closures further down.
        let pageMarks = marks.snapshot(of: (firstPage..<(firstPage + unit.pageCount)).flatMap { corpus.page($0)?.ayahs ?? [] })
        Group {
            switch unit {
            case .spread: spread(pageMarks)
            case .single: pageView(firstPage, gutter: nil, marks: pageMarks)
            case .widthFit: widthFitted(pageMarks)
            }
        }
        // A tap on words or lines selects an ayah there; a tap anywhere else on the page (header,
        // footer, margins, empty slots) reaches this one.
        .contentShape(.rect)
        .onTapGesture { chromeToggle?.toggle() }
    }

    /// iPhone landscape: the page as wide as the screen and as tall as the page's proportions make
    /// it; the reader scrolls down within the page and swipes sideways to the next one.
    private func widthFitted(_ marks: QuranAyahMarkSnapshot) -> some View {
        GeometryReader { proxy in
            let size = Self.widthFittedPageSize(width: min(proxy.size.width, maxPageWidth ?? .infinity), style: corpus.style)
            ScrollView(.vertical) {
                pageView(firstPage, gutter: nil, marks: marks)
                    .frame(width: size.width, height: size.height)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.automatic)
            // Each page starts at its top line.
            .id(firstPage)
        }
    }

    /// The size of a page fitted to `width`: the slot height follows from the width-fitted page, so
    /// the height is unbounded.
    static func widthFittedPageSize(width: CGFloat, style: MushafStyle) -> CGSize {
        CGSize(width: width, height: (width / style.pageAspectRatio).rounded())
    }

    private func spread(_ marks: QuranAyahMarkSnapshot) -> some View {
        // Laid out right-to-left: the first (odd) page is drawn on the right.
        HStack(spacing: 0) {
            if let fold {
                // Facing pages share one width (the narrower side's) and hug the gutter, so an
                // off-centre fold never gives them different line lengths.
                let pageWidth = min(fold.leadingWidth, fold.trailingWidth)
                pageView(firstPage, gutter: .trailing, marks: marks)
                    .frame(width: pageWidth)
                    .frame(width: fold.leadingWidth, alignment: .trailing)
                Color.clear
                    .frame(width: fold.gutterWidth)
                pageView(firstPage + 1, gutter: .leading, marks: marks)
                    .frame(width: pageWidth)
                    .frame(width: fold.trailingWidth, alignment: .leading)
            } else {
                pageView(firstPage, gutter: .trailing, marks: marks)
                pageView(firstPage + 1, gutter: .leading, marks: marks)
            }
        }
        .environment(\.mushafFontSizeCap, sharedFontSize)
        .onPreferenceChange(MushafFontSizeKey.self) { sharedFontSize = $0 }
    }

    @ViewBuilder
    private func pageView(_ number: Int, gutter: HorizontalAlignment?, marks: QuranAyahMarkSnapshot) -> some View {
        if let page = corpus.page(number) {
            MushafPageView(
                style: corpus.style,
                page: page,
                basmala: corpus.basmala,
                surahs: corpus.surahs,
                services: services,
                selectedAyah: state.selectedAyah,
                marks: marks,
                marginMarkers: settings.showsMarginMarkers ? corpus.marginMarkers(page: number) : [],
                gutterEdge: gutter,
                onSelect: onSelect
            )
        } else {
            Color.clear
        }
    }
}

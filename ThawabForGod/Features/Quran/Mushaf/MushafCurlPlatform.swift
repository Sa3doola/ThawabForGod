//
//  MushafCurlPlatform.swift
//  ThawabForGod
//

import Observation
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// What this platform's pager can do. The page curl is `UIPageViewController`, so it is iOS and
/// iPadOS only; the Mac always slides.
enum MushafPagerPlatform {
    static var supportsCurl: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
}

/// The Mushaf as a book that turns like paper: a `UIPageViewController(.pageCurl)` laid out for an
/// Arabic book. Spine is fixed at creation, so the owner puts `.id(unit)` on this view.
///
/// On the Mac this is `EmptyView` and is never built (`MushafPagerPlatform.supportsCurl` is false).
struct MushafCurlPager: View {
    let corpus: QuranCorpus
    let state: MushafReadingState
    let settings: QuranReaderSettings
    let services: MushafRenderServices
    let unit: MushafPageUnit
    let fold: FoldGeometry?
    let sideInsets: EdgeInsets
    let marks: QuranAyahMarks
    let onSelect: (VerseReference) -> Void

    init(
        corpus: QuranCorpus,
        state: MushafReadingState,
        settings: QuranReaderSettings,
        services: MushafRenderServices,
        unit: MushafPageUnit,
        fold: FoldGeometry?,
        sideInsets: EdgeInsets,
        marks: QuranAyahMarks,
        onSelect: @escaping (VerseReference) -> Void
    ) {
        self.corpus = corpus
        self.state = state
        self.settings = settings
        self.services = services
        self.unit = unit
        self.fold = fold
        self.sideInsets = sideInsets
        self.marks = marks
        self.onSelect = onSelect
    }

    var body: some View {
        #if os(iOS)
        MushafCurlController(
            corpus: corpus, state: state, settings: settings, services: services, unit: unit,
            fold: fold, sideInsets: sideInsets, marks: marks, onSelect: onSelect
        )
        #else
        EmptyView()
        #endif
    }
}

#if os(iOS)

/// What a live page depends on beyond the page number. The hosted pages are rebuilt only when this
/// changes, not on every SwiftUI update (a page turn would otherwise redraw three pages).
private struct MushafCurlRefresh: Equatable {
    let unit: MushafPageUnit
    let fold: FoldGeometry?
    let sideInsets: EdgeInsets
    let palette: ReadingPalette
    let colorScheme: ColorScheme
    let dynamicTypeSize: DynamicTypeSize
    let faces: QuranFaces
    let showsMarginMarkers: Bool
}

/// A hosted Mushaf page, remembering which page it shows.
private final class MushafCurlHost: UIHostingController<MushafCurlPage> {
    var page = 0
}

struct MushafCurlController: UIViewControllerRepresentable {
    let corpus: QuranCorpus
    let state: MushafReadingState
    let settings: QuranReaderSettings
    let services: MushafRenderServices
    let unit: MushafPageUnit
    let fold: FoldGeometry?
    let sideInsets: EdgeInsets
    let marks: QuranAyahMarks
    let onSelect: (VerseReference) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(input: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        context.coordinator.makePageViewController(environment: context.environment)
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.update(input: self, environment: context.environment)
    }

    static func dismantleUIViewController(_ pageViewController: UIPageViewController, coordinator: Coordinator) {
        coordinator.stop()
    }

    /// Data source, delegate and the pool of hosted pages. All of it runs on the main actor.
    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        private var input: MushafCurlController
        private var environment = EnvironmentValues()
        private weak var pageViewController: UIPageViewController?
        private let fontCap = MushafSpreadFontCap()

        /// Hosted pages by page number: at most three units (three controllers, six in a spread).
        private var pool: [Int: MushafCurlHost] = [:]
        /// First page of the unit the curl shows (or is animating to).
        private var displayedFirst: Int
        /// A curl is in flight (a gesture or an animated `setViewControllers`): the controller
        /// must not be touched, `setViewControllers` asserts.
        private var isTurning = false
        /// Pages handed to UIKit during a gesture that are not in `viewControllers` yet; a later miss
        /// in the same gesture must not reuse them. Cleared when the transition ends.
        private var handedOut: Set<Int> = []
        /// The latest page the reader asked for during a curl, applied when it ends.
        private var pendingTarget: Int?
        private var isActive = true
        private var refreshKey: MushafCurlRefresh?

        init(input: MushafCurlController) {
            self.input = input
            self.displayedFirst = input.unit.unitStart(for: input.state.page)
        }

        private var spine: MushafCurlOrder.Spine { MushafCurlOrder.Spine(unit: input.unit) }
        private var poolLimit: Int { 3 * input.unit.pageCount }

        // MARK: Setup

        func makePageViewController(environment: EnvironmentValues) -> UIPageViewController {
            self.environment = environment
            refreshKey = currentRefreshKey()
            let isSpread = spine == .spread
            let location: UIPageViewController.SpineLocation = isSpread ? .mid : .max
            let controller = UIPageViewController(
                transitionStyle: .pageCurl,
                navigationOrientation: .horizontal,
                options: [.spineLocation: NSNumber(value: location.rawValue)]
            )
            // A spread's back sides are pages of their own, and `.mid` requires it.
            controller.isDoubleSided = isSpread
            controller.dataSource = self
            controller.delegate = self
            // The direction is entirely `MushafCurlOrder`'s, and the same in English and Arabic.
            controller.view.semanticContentAttribute = .forceLeftToRight
            controller.view.backgroundColor = UIColor(environment.readingPalette.background)
            // Swipe only: a tap on words selects an ayah and must never turn the page.
            for recognizer in controller.gestureRecognizers where recognizer is UITapGestureRecognizer {
                controller.view.removeGestureRecognizer(recognizer)
            }
            pageViewController = controller
            controller.setViewControllers(hosts(for: displayedFirst), direction: .forward, animated: false)
            observePage()
            return controller
        }

        func update(input: MushafCurlController, environment: EnvironmentValues) {
            self.input = input
            self.environment = environment
            let key = currentRefreshKey()
            if key != refreshKey {
                refreshKey = key
                refreshPages()
            }
            sync()
        }

        func stop() {
            isActive = false
        }

        private func currentRefreshKey() -> MushafCurlRefresh {
            MushafCurlRefresh(
                unit: input.unit,
                fold: input.fold,
                sideInsets: input.sideInsets,
                palette: environment.readingPalette,
                colorScheme: environment.colorScheme,
                dynamicTypeSize: environment.dynamicTypeSize,
                faces: environment.quranFaces,
                showsMarginMarkers: input.settings.showsMarginMarkers
            )
        }

        /// Gives every pooled page the new inputs and environment. Rebuilding the root view keeps
        /// the controller, so nothing is allocated.
        private func refreshPages() {
            fontCap.sizes.removeAll()
            let background = UIColor(environment.readingPalette.background)
            pageViewController?.view.backgroundColor = background
            for host in pool.values {
                host.rootView = makePage(host.page)
                host.view.backgroundColor = background
            }
        }

        private func makePage(_ page: Int) -> MushafCurlPage {
            let isSpread = spine == .spread
            return MushafCurlPage(
                corpus: input.corpus,
                state: input.state,
                settings: input.settings,
                services: input.services,
                page: page,
                gutter: isSpread ? (page % 2 == 1 ? .trailing : .leading) : nil,
                marks: input.marks,
                fontCap: isSpread ? fontCap : nil,
                spineInset: isSpread ? (input.fold?.gutterWidth ?? 0) / 2 : 0,
                outerInsets: input.fold == nil ? input.sideInsets : EdgeInsets(),
                hostEnvironment: environment,
                onSelect: input.onSelect
            )
        }

        // MARK: Pool

        /// The controllers for the unit starting at `first`, in UIKit's order.
        private func hosts(for first: Int) -> [UIViewController] {
            let pages = MushafCurlOrder.pages(inUnitStarting: first, spine: spine)
            let hosts = pages.map { host(for: $0, alsoProtecting: Set(pages)) }
            handedOut.formUnion(pages)
            return hosts
        }

        /// The hosted page for `page`. A miss reuses the page farthest from the reader that is
        /// neither on screen nor being asked for, and only makes a controller below the limit.
        private func host(for page: Int, alsoProtecting extra: Set<Int> = []) -> MushafCurlHost {
            if let existing = pool[page] { return existing }
            var protected = extra.union([page]).union(handedOut)
            protected.formUnion((pageViewController?.viewControllers ?? []).compactMap { ($0 as? MushafCurlHost)?.page })
            if let pendingTarget {
                protected.formUnion(MushafCurlOrder.pages(inUnitStarting: pendingTarget, spine: spine))
            }
            if pool.count >= poolLimit,
               let victim = pool.keys.filter({ !protected.contains($0) }).max(by: { abs($0 - displayedFirst) < abs($1 - displayedFirst) }),
               let reused = pool.removeValue(forKey: victim) {
                reused.page = page
                reused.rootView = makePage(page)
                pool[page] = reused
                return reused
            }
            let created = MushafCurlHost(rootView: makePage(page))
            created.page = page
            created.safeAreaRegions = []
            created.view.backgroundColor = UIColor(environment.readingPalette.background)
            pool[page] = created
            return created
        }

        // MARK: Following the reading state

        /// Watches `state.page` without depending on SwiftUI calling `update`, re-armed after each change.
        private func observePage() {
            guard isActive else { return }
            withObservationTracking {
                _ = input.state.page
            } onChange: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, isActive else { return }
                    sync()
                    observePage()
                }
            }
        }

        /// Brings the curl to the unit that holds `state.page`.
        private func sync() {
            let target = input.unit.unitStart(for: input.state.page)
            if isTurning {
                pendingTarget = target
                return
            }
            move(to: target)
        }

        /// Animated only for a one-unit step; Go to and the previous/next surah keys set it directly.
        private func move(to target: Int) {
            guard let pageViewController, target != displayedFirst else { return }
            let step = abs(target - displayedFirst)
            let direction = MushafCurlOrder.direction(from: displayedFirst, to: target, spine: spine)
            let controllers = hosts(for: target)
            displayedFirst = target
            let uiKitDirection: UIPageViewController.NavigationDirection = direction == .forward ? .forward : .reverse
            guard step == input.unit.pageCount else {
                pageViewController.setViewControllers(controllers, direction: uiKitDirection, animated: false)
                return
            }
            isTurning = true
            pageViewController.setViewControllers(controllers, direction: uiKitDirection, animated: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.turnEnded() }
            }
        }

        private func turnEnded() {
            isTurning = false
            if let target = pendingTarget {
                pendingTarget = nil
                move(to: target)
            }
        }

        // MARK: UIPageViewControllerDataSource

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let host = viewController as? MushafCurlHost,
                  let page = MushafCurlOrder.pageBefore(host.page, spine: spine, pages: input.state.pages) else { return nil }
            return self.host(for: page)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let host = viewController as? MushafCurlHost,
                  let page = MushafCurlOrder.pageAfter(host.page, spine: spine, pages: input.state.pages) else { return nil }
            return self.host(for: page)
        }

        // MARK: UIPageViewControllerDelegate

        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            isTurning = true
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            isTurning = false
            handedOut = []
            if completed { settle(on: pageViewController) }
            if let target = pendingTarget {
                pendingTarget = nil
                move(to: target)
            }
        }

        /// A finished gesture: read the page from the controller and record it.
        private func settle(on controller: UIPageViewController) {
            let visible = (controller.viewControllers ?? []).compactMap { ($0 as? MushafCurlHost)?.page }
            guard let first = MushafCurlOrder.unitStart(ofVisible: visible) else { return }
            let unit = input.unit
            let state = input.state
            // A report more than one unit from the reader is stray: go back to where they are.
            guard MushafPagerStep.accepts(reported: first, page: state.page, pageCount: unit.pageCount, jumpTarget: nil) else {
                displayedFirst = first
                move(to: unit.unitStart(for: state.page))
                return
            }
            displayedFirst = first
            // Keep the exact page if it is still visible (the left page of a spread).
            if !(first...(first + unit.pageCount - 1)).contains(state.page) { state.show(page: first) }
        }
    }
}

#endif

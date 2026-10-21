//
//  MushafCurlPage.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// The smallest fitted font size among the two pages of a spread in the curl, so facing pages share
/// one size as they do in the sliding pager (where `MushafUnitView` keeps it in `@State`). Each
/// hosted page is its own SwiftUI root, so the share lives in an object they all hold.
@Observable
@MainActor
final class MushafSpreadFontCap {
    /// Each page's own fitted size, reported through `MushafFontSizeKey`.
    var sizes: [Int: CGFloat] = [:]

    /// The cap for `page`: the smaller of its size and its partner's (odd n pairs with n + 1).
    func cap(for page: Int) -> CGFloat {
        let partner = page % 2 == 1 ? page + 1 : page - 1
        return min(sizes[page] ?? .infinity, sizes[partner] ?? .infinity)
    }
}

/// The root view of one hosting controller in the page curl: one Mushaf page.
///
/// A hosting controller does not inherit SwiftUI's environment, so the representable hands in a
/// copy and this view applies it, then forces right-to-left as the sliding pager does. The page
/// itself is the same `MushafPageView` the slide draws, so the Quran text is untouched.
struct MushafCurlPage: View {
    let corpus: QuranCorpus
    let state: MushafReadingState
    let settings: QuranReaderSettings
    let services: MushafRenderServices
    let page: Int
    /// In a spread, the edge facing the other page; `nil` for a single page.
    let gutter: HorizontalAlignment?
    let marks: QuranAyahMarks
    /// Shared by the two halves of a spread; `nil` for a single page.
    let fontCap: MushafSpreadFontCap?
    /// Half the fold's gutter, padded on the spine side (zero without a fold).
    var spineInset: CGFloat = 0
    /// The side safe-area insets, applied on the outer edge (zero when a fold places the pages).
    var outerInsets = EdgeInsets()
    /// The environment of the view that owns the curl.
    let hostEnvironment: EnvironmentValues
    let onSelect: (VerseReference) -> Void

    var body: some View {
        MushafCurlPageContent(
            corpus: corpus, state: state, settings: settings, services: services, page: page,
            gutter: gutter, marks: marks, fontCap: fontCap, spineInset: spineInset,
            outerInsets: outerInsets, onSelect: onSelect
        )
        .environment(\.self, hostEnvironment)
        // Forced whatever the interface language: a Mushaf always pages right-to-left.
        .environment(\.layoutDirection, .rightToLeft)
    }
}

/// The page itself. Separate from `MushafCurlPage` because it reads the environment, and it must
/// read the copy that `MushafCurlPage` applies rather than the hosting controller's empty one.
private struct MushafCurlPageContent: View {
    let corpus: QuranCorpus
    let state: MushafReadingState
    let settings: QuranReaderSettings
    let services: MushafRenderServices
    let page: Int
    let gutter: HorizontalAlignment?
    let marks: QuranAyahMarks
    let fontCap: MushafSpreadFontCap?
    let spineInset: CGFloat
    let outerInsets: EdgeInsets
    let onSelect: (VerseReference) -> Void

    @Environment(\.mushafChromeToggle) private var chromeToggle

    var body: some View {
        // Read at the top level of this body so the page observes the store and the selection.
        let pageMarks = marks.snapshot(of: corpus.page(page)?.ayahs ?? [])
        let selected = state.selectedAyah
        let markers = settings.showsMarginMarkers ? corpus.marginMarkers(page: page) : []
        content(marks: pageMarks, selected: selected, markers: markers)
            .padding(insets)
            .contentShape(.rect)
            // A tap on words selects an ayah there; anywhere else it reaches this one.
            .onTapGesture { chromeToggle?.toggle() }
    }

    @ViewBuilder
    private func content(marks: QuranAyahMarkSnapshot, selected: VerseReference?, markers: [MushafMarginMarker]) -> some View {
        if let mushafPage = corpus.page(page) {
            let view = MushafPageView(
                style: corpus.style,
                page: mushafPage,
                basmala: corpus.basmala,
                surahs: corpus.surahs,
                services: services,
                selectedAyah: selected,
                marks: marks,
                marginMarkers: markers,
                gutterEdge: gutter,
                onSelect: onSelect
            )
            if let fontCap {
                view
                    .environment(\.mushafFontSizeCap, fontCap.cap(for: page))
                    .onPreferenceChange(MushafFontSizeKey.self) { fontCap.sizes[page] = $0 }
            } else {
                view
            }
        } else {
            Color.clear
        }
    }

    /// The outer edge takes the safe-area inset; the spine edge takes half the fold's gutter.
    /// Laid out right-to-left, so `leading` is the right-hand side.
    private var insets: EdgeInsets {
        if gutter == .trailing {
            return EdgeInsets(top: 0, leading: outerInsets.leading, bottom: 0, trailing: spineInset)
        } else if gutter == .leading {
            return EdgeInsets(top: 0, leading: spineInset, bottom: 0, trailing: outerInsets.trailing)
        }
        return outerInsets
    }
}

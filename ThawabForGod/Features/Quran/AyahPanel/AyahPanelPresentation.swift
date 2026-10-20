//
//  AyahPanelPresentation.swift
//  ThawabForGod
//

import SwiftUI

/// Where the ayah panel goes: a trailing column inside the reader where the reader is wide (iPad
/// landscape, the Mac, one half of a vertically folded display), a sheet everywhere else.
///
/// **Our own column, not `.inspector`.** Any `.inspector` inside the split view's detail column pops
/// the reader that was pushed there: found on the iPad in M7.1 (even never presented, and wherever it
/// was attached) and again on the Mac in M8 (B2: tapping a surah in the library opened the reader and
/// popped it at once). The column is a plain `HStack` child of the reader, which cannot touch a
/// navigation stack.
///
/// The rule is measured on a `GeometryReader` around the *whole* `HStack` (reader and column), so
/// opening the column narrows the reader without changing the answer and the layout cannot flip.
nonisolated enum AyahPanelLayout {
    enum Platform: Sendable {
        case iOS, macOS

        static var current: Platform {
            #if os(macOS)
            .macOS
            #else
            .iOS
            #endif
        }
    }

    static let minimumWidth: CGFloat = 320
    static let maximumWidth: CGFloat = 420

    /// False while unmeasured (width or height <= 0). macOS: always (the column is capped at half the
    /// reader, so a narrow window still gets it). iOS: on a fold, or regular width in landscape.
    static func usesSidePanel(size: CGSize, isCompact: Bool, hasFold: Bool, platform: Platform = .current) -> Bool {
        guard size.width > 0, size.height > 0 else { return false }
        switch platform {
        case .macOS: return true
        case .iOS: return hasFold || (!isCompact && size.width > size.height)
        }
    }

    /// On a fold, the trailing half plus the hinge; otherwise 36% of the reader, within 320...420
    /// and never more than half the reader.
    static func sidePanelWidth(containerWidth: CGFloat, fold: FoldGeometry?) -> CGFloat {
        if let fold { return fold.trailingWidth + fold.gutterWidth }
        return min(max(containerWidth * 0.36, minimumWidth), maximumWidth, containerWidth / 2)
    }
}

extension View {
    /// Presents the ayah panel beside or over the reader, driven by the coordinator's flags.
    func quranAyahPanel(
        coordinator: QuranCoordinator,
        panel: AyahPanelViewModel,
        reader: QuranReaderViewModel,
        userData: QuranUserDataStore,
        palette: ReadingPalette,
        faces: QuranFaces
    ) -> some View {
        modifier(
            AyahPanelPresentation(
                coordinator: coordinator, panel: panel, reader: reader, userData: userData, palette: palette, faces: faces
            )
        )
    }

    /// The note editor's size where a sheet takes its content's: room on the Mac, nothing on iOS.
    func quranNoteEditorFrame() -> some View {
        #if os(macOS)
        frame(minWidth: 460, idealWidth: 520, minHeight: 360, idealHeight: 420)
        #else
        self
        #endif
    }
}

/// A modifier, not code in `QuranReaderView.body`: the flags are read here, so opening the panel
/// does not re-run the reader's body (design note M5.1).
private struct AyahPanelPresentation: ViewModifier {
    let coordinator: QuranCoordinator
    let panel: AyahPanelViewModel
    let reader: QuranReaderViewModel
    let userData: QuranUserDataStore
    let palette: ReadingPalette
    let faces: QuranFaces

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @Environment(\.foldOverride) private var foldOverride
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What the placement rule is decided from; one value so a single `onChange` watches all of it.
    private struct Placement: Equatable {
        let size: CGSize
        let isCompact: Bool
        let fold: FoldGeometry?
    }

    func body(content: Content) -> some View {
        @Bindable var coordinator = coordinator
        let shown = coordinator.isPanelInspectorPresented
        GeometryReader { proxy in
            let fold = FoldGeometry.resolve(in: proxy, override: foldOverride)
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.mushafPanelCoversFold, shown && fold != nil)
                // The animation is scoped to the column: on the whole reader it would also animate
                // the pager re-laying out narrower.
                Group {
                    if shown {
                        AyahSidePanel(
                            coordinator: coordinator, panel: panel, reader: reader, userData: userData,
                            gutter: fold?.gutterWidth ?? 0
                        )
                        .environment(\.readingPalette, palette)
                        .environment(\.quranFaces, faces)
                        .frame(width: AyahPanelLayout.sidePanelWidth(containerWidth: proxy.size.width, fold: fold))
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(reduceMotion ? nil : .default, value: shown)
            }
            .onChange(of: Placement(size: proxy.size, isCompact: isCompact, fold: fold), initial: true) { _, placement in
                coordinator.panelUsesInspector = AyahPanelLayout.usesSidePanel(
                    size: placement.size, isCompact: placement.isCompact, hasFold: placement.fold != nil
                )
            }
        }
        // The keyboard shrinks the measured height; on an iPad in portrait that would flip the rule
        // and swap the sheet for the column while a note is being typed.
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $coordinator.isPanelSheetPresented) {
            sheetPanel
        }
    }

    private var isCompact: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    /// The panel with the reader's palette and faces, set again because a sheet is not guaranteed
    /// to see values the reader computed rather than inherited.
    private var sheetPanel: some View {
        AyahPanel(coordinator: coordinator, panel: panel, reader: reader, userData: userData, isInspector: false)
            .environment(\.readingPalette, palette)
            .environment(\.quranFaces, faces)
    }
}

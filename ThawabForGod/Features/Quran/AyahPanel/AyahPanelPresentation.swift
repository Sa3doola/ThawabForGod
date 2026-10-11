//
//  AyahPanelPresentation.swift
//  ThawabForGod
//

import SwiftUI

/// Where the ayah panel goes: an inspector beside the page where the reader is wide (iPad
/// landscape, the Mac), a sheet everywhere else. Mushaf's rule, measured on the reader view, which
/// is the detail column, rather than on the screen.
nonisolated enum AyahPanelLayout {
    static func usesInspector(size: CGSize, isCompact: Bool) -> Bool {
        #if os(macOS)
        true
        #else
        // Never on iOS: an `.inspector` attached to the reader, which is pushed inside the split
        // view's detail column, pops the reader as soon as it is pushed (found on an iPad simulator).
        // The sheet is the panel there, at every width.
        false
        #endif
    }
}

extension View {
    /// Presents the ayah panel over the reader, driven by the coordinator's flags.
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
    @State private var readerSize: CGSize = .zero

    func body(content: Content) -> some View {
        @Bindable var coordinator = coordinator
        content
            .onChange(of: usesInspector, initial: true) { _, wide in
                coordinator.panelUsesInspector = wide
            }
            .sheet(isPresented: $coordinator.isPanelSheetPresented) {
                panelView(isInspector: false)
            }
            .quranPanelInspector(isPresented: $coordinator.isPanelInspectorPresented) {
                panelView(isInspector: true)
            }
            // After the inspector, so it measures the reader at full width. Measured inside, the
            // inspector's own column would narrow the reader, flip the layout and close it again.
            .onGeometryChange(for: CGSize.self) { $0.size } action: { readerSize = $0 }
    }

    private var usesInspector: Bool {
        AyahPanelLayout.usesInspector(size: readerSize, isCompact: isCompact)
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
    private func panelView(isInspector: Bool) -> some View {
        AyahPanel(coordinator: coordinator, panel: panel, reader: reader, userData: userData, isInspector: isInspector)
            .environment(\.readingPalette, palette)
            .environment(\.quranFaces, faces)
    }
}

private extension View {
    /// The inspector, on the Mac only. See `AyahPanelLayout.usesInspector`.
    @ViewBuilder
    func quranPanelInspector<Panel: View>(isPresented: Binding<Bool>, @ViewBuilder panel: () -> Panel) -> some View {
        #if os(macOS)
        inspector(isPresented: isPresented) {
            panel().inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        }
        #else
        self
        #endif
    }
}

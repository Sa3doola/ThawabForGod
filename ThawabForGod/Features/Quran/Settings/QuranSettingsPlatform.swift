//
//  QuranSettingsPlatform.swift
//  ThawabForGod
//

import SwiftUI

/// The platform differences of the Quran settings screens, in one file: the only `#if os` they have.
enum QuranSettingsPlatform {
    /// Keeping the screen awake is a phone and tablet idea; the Mac has no idle timer to hold.
    static var showsKeepScreenAwake: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
}

extension View {
    /// A Mac sheet takes its content's size, and a pushed list has none of its own, so without a
    /// frame the sheet collapses to its title. Elsewhere the sheet is sized by the system.
    func quranSettingsSheetFrame() -> some View {
        #if os(macOS)
        frame(minWidth: 460, minHeight: 560)
        #else
        self
        #endif
    }

    /// The Edit button the pack lists need for drag-to-reorder on iOS. The Mac list reorders by
    /// dragging directly.
    func quranPacksEditButton() -> some View {
        #if os(iOS)
        toolbar { EditButton() }
        #else
        self
        #endif
    }

    /// Mirrors "is the horizontal size class compact" into `isCompact`. Always `false` on the Mac,
    /// which has no size classes.
    func quranCompactWidth(_ isCompact: Binding<Bool>) -> some View {
        #if os(iOS)
        modifier(QuranCompactWidthReader(isCompact: isCompact))
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct QuranCompactWidthReader: ViewModifier {
    @Binding var isCompact: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .onChange(of: horizontalSizeClass, initial: true) { _, sizeClass in
                isCompact = sizeClass == .compact
            }
    }
}
#endif

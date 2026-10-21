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

    /// The page curl is UIKit's (`UIPageViewController`); the Mac has no curl to choose.
    static var showsPageTurn: Bool {
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

    /// The sheet's title and Done. On iOS they are a header outside the scrolling form, because on the
    /// iPhone Duo the system's navigation bar went up with the form's content (BUGS.md B9); a header
    /// that is not part of the scroll view cannot. The Mac sheet keeps the toolbar's Done.
    @ViewBuilder
    func quranSettingsPinnedHeader(title: String, done: String, action: @escaping () -> Void) -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                QuranSettingsHeader(title: title, done: done, action: action)
            }
        #else
        toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: action) { Text(done) }
                    .accessibilityIdentifier("quran.settings.done")
            }
        }
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

#if os(iOS)
private struct QuranSettingsHeader: View {
    let title: String
    let done: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Text(title)
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)
                // Room either side for Done, so a long title or a large text size shrinks rather
                // than running under it.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 72)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Spacer()
                Button(action: action) { Text(done).appFont(.headline) }
                    .accessibilityIdentifier("quran.settings.done")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
#endif

//
//  AyahMarksAccessibility.swift
//  ThawabForGod
//

import SwiftUI

extension HighlightColor {
    /// The colour's name, for the highlight menu and VoiceOver.
    /// Requires the `quranHighlight*` cases of `L10nKey` (M6.2 §6).
    var titleKey: L10nKey {
        switch self {
        case .yellow: .quranHighlightYellow
        case .green: .quranHighlightGreen
        case .blue: .quranHighlightBlue
        case .pink: .quranHighlightPink
        }
    }
}

extension View {
    /// Reads an ayah's bookmark, highlight and note as custom content ("more content"), so the
    /// ayah stays one VoiceOver element in both renderers.
    func ayahMarksAccessibility(_ marks: QuranAyahMarkSnapshot, ayah: VerseReference) -> some View {
        modifier(AyahMarksAccessibility(marks: marks, ayah: ayah))
    }
}

private struct AyahMarksAccessibility: ViewModifier {
    let marks: QuranAyahMarkSnapshot
    let ayah: VerseReference

    @Environment(LocalizationManager.self) private var l10n

    func body(content: Content) -> some View {
        content
            .accessibilityCustomContent(
                AccessibilityCustomContentKey(Text(l10n.string(.quranBookmarkTitle)), id: "bookmark"),
                marks.isBookmarked(ayah) ? Text(l10n.string(.quranBookmarked)) : nil
            )
            .accessibilityCustomContent(
                AccessibilityCustomContentKey(Text(l10n.string(.quranHighlight)), id: "highlight"),
                marks.highlight(ayah).map { Text(l10n.string($0.titleKey)) }
            )
            .accessibilityCustomContent(
                AccessibilityCustomContentKey(Text(l10n.string(.quranNote)), id: "note"),
                marks.note(ayah).map { Text(verbatim: $0) }
            )
    }
}

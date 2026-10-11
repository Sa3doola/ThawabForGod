//
//  SeparatedReaderView.swift
//  ThawabForGod
//

import SwiftUI

/// A request to scroll to an ayah of the surah on screen. `serial` makes two requests for the
/// same ayah different values.
nonisolated struct SeparatedScrollRequest: Equatable, Sendable {
    let ayah: VerseReference
    let serial: Int
}

/// One surah as a vertical list of ayahs, at the reader's own size and face — the separated mode,
/// and the whole Quran reader in a build without the printed pages.
///
/// Ported from Mushaf's `SeparatedReaderView`, rendering only: the translations under each ayah,
/// the context menu and the panel arrive with the screens (M5), the bookmark and note marks with
/// the user data (M6). Two of Noor's lessons are kept from its own reader: the header, the basmala
/// and every row are **siblings** in the `LazyVStack` — a stack is lazy only in its direct
/// children, and nesting a surah in one child built all 286 rows of Al-Baqara before the first
/// frame — and the position is reported as it changes rather than written on the way out.
struct SeparatedReaderView: View {
    let surah: Surah
    let ayahs: ArraySlice<Ayah>
    let basmala: String
    let selectedAyah: VerseReference?
    var marks: QuranAyahMarks = .none
    /// The ayah to open at, read once when the view appears; `nil` opens at the top.
    var initialAyah: VerseReference?
    /// A jump to an ayah of this surah while it is on screen. Not read at creation: a list being
    /// created is positioned by `initialAyah`.
    var scrollRequest: SeparatedScrollRequest? = nil
    let onSelect: (VerseReference) -> Void
    /// The ayah now at the top of the viewport, as the reader scrolls.
    var onTopAyahChange: (VerseReference) -> Void = { _ in }
    /// Every installed translation of this surah, shown under each ayah. Read only here.
    let translations: SeparatedTranslationsModel
    /// The surah after this one; `nil` at An-Nas, where there is no footer.
    var nextSurah: Surah? = nil
    var onNextSurah: (Int) -> Void = { _ in }
    /// `nil`: no Surah Info menu on the banner.
    var onShowSurahInfo: ((Int) -> Void)? = nil

    @Environment(LocalizationManager.self) private var l10n
    @Environment(QuranReaderSettings.self) private var settings
    @Environment(\.readingPalette) private var palette
    @Environment(\.quranFaces) private var faces
    @Environment(\.readingStyle) private var style
    /// The interface's direction, read before the Quran's right-to-left override below, so the
    /// footer can be laid out the way the rest of the app is.
    @Environment(\.layoutDirection) private var interfaceDirection
    /// The multiplier `readingFont(size:)` applies, for the stretches whose face is named inside an
    /// attributed string and the translations' size.
    @ScaledMetric(relativeTo: .title3) private var typeScale: CGFloat = 1

    /// Ayah at the top of the viewport.
    @State private var topAyah: VerseReference?
    /// Whether the initial jump has happened; it happens once, after the translations settle.
    @State private var didJump = false

    /// Widest the surah header gets on iPad and the Mac.
    private static let headerMaxWidth: CGFloat = 560

    /// What the translations depend on: reload for another surah or the toggle.
    private struct TranslationKey: Hashable {
        let surah: Int
        let isShown: Bool
        let enabled: [ContentPackID]?
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    banner
                    if surah.hasBasmalaLine {
                        Text(basmalaText)
                            .readingFont(size: settings.textSize)
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    ForEach(ayahs) { ayah in
                        SeparatedAyahRow(
                            ayah: ayah,
                            surahName: surah.name(in: l10n.language),
                            textSize: settings.textSize,
                            translations: translations.translations(for: ayah.id),
                            isSelected: selectedAyah == ayah.id,
                            highlight: marks.highlight(ayah.id)
                        ) {
                            onSelect(ayah.id)
                        }
                        .id(ayah.id)
                    }
                    // A sibling with no `.id`: the scroll position is typed `VerseReference`.
                    if let nextSurah {
                        SeparatedSurahFooter(next: nextSurah) { onNextSurah(nextSurah.number) }
                            .environment(\.layoutDirection, interfaceDirection)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal)
            }
            .scrollPosition(id: $topAyah, anchor: .top)
            .task(id: TranslationKey(
                surah: surah.number, isShown: settings.showsTranslationInSeparated, enabled: settings.enabledTranslations
            )) {
                await translations.load(
                    surah: surah.number, isShown: settings.showsTranslationInSeparated, enabled: settings.enabledTranslations
                )
                // Jump to the requested ayah once, after the translations have settled so rows above
                // it do not grow afterwards. `scrollTo` also reaches rows the lazy stack has not
                // built yet (`scrollPosition(id:)` ignores its initial value).
                guard !Task.isCancelled, !didJump else { return }
                didJump = true
                guard topAyah == nil, let initialAyah, initialAyah.verse > 1 else { return }
                await Task.yield()
                proxy.scrollTo(initialAyah, anchor: .top)
            }
            .onChange(of: scrollRequest) { _, request in
                guard let request, request.ayah.surah == surah.number else { return }
                proxy.scrollTo(request.ayah, anchor: .top)
            }
        }
        // Quran text is right-to-left whatever the interface language.
        .environment(\.layoutDirection, .rightToLeft)
        .background(palette.background)
        .onChange(of: topAyah) { _, ayah in
            if let ayah { onTopAyahChange(ayah) }
        }
    }

    /// The banner, with the Surah Info menu when the build has surah information.
    @ViewBuilder
    private var banner: some View {
        let base = SeparatedSurahBanner(surah: surah, name: surah.name(in: l10n.language))
            .frame(maxWidth: Self.headerMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        if let onShowSurahInfo {
            let number = surah.number
            base
                .contextMenu {
                    Button { onShowSurahInfo(number) } label: {
                        Label(l10n.string(.quranSurahInfo), systemImage: "info.circle")
                    }
                }
                .accessibilityAction(named: Text(l10n.string(.quranSurahInfo))) { onShowSurahInfo(number) }
        } else {
            base
        }
    }

    /// The basmala through the same drawing-only fallback as the rows; the characters are untouched.
    private var basmalaText: AttributedString {
        QuranAyahText.attributed(
            basmala,
            face: style.font,
            scaledSize: settings.textSize * Double(typeScale),
            hafsIsRegistered: faces.contains(.ayahText)
        )
    }
}

/// The printed surah header over a surah in separated mode: the same glyph as on a Mushaf page, as
/// wide as the column up to a readable maximum.
private struct SeparatedSurahBanner: View {
    let surah: Surah
    let name: String

    var body: some View {
        Color.clear
            .aspectRatio(MushafPageMetrics.headerAdvanceEm / MushafPageMetrics.headerHeightEm, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    SurahHeaderGlyph(surah: surah, name: name, fontSize: geometry.size.width / MushafPageMetrics.headerAdvanceEm)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }
}

//
//  ReaderSettingsSheet.swift
//  ThawabForGod
//

import SwiftUI

/// The reading panel: the page's colour, the face, the verse-number medallion, the size of the
/// text and the space between its lines.
///
/// **It opens on a preview, which it used to refuse.** The argument against was that the reader's
/// own verses behind the half-height sheet are a better likeness than any sample — and for paper
/// and size they still are. But a *face* and a *medallion* are chosen by comparing shapes, and at
/// `.large`, on a Mac where the panel covers the page, or with the verse behind scrolled to the
/// middle of a long line, there is nothing of either in view. One short verse and its number, drawn
/// with everything the panel controls, is the one place all of it can be seen at once. The verse
/// is 112:1, the shortest complete statement in the mushaf, so it fits a line at every size.
///
/// Each control writes straight through to `ReaderSettings`, which persists as it goes. Nothing
/// here is staged and applied on Done — there is no Cancel, because there is nothing to cancel:
/// every change is already visible behind the sheet and `Reset` is the way back.
struct ReaderSettingsSheet: View {
    let settings: ReaderSettings
    let coordinator: QuranCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                paperSection
                fontSection
                markerSection
                textSection
                pageSection
                resetSection
            }
            .navigationTitle(l10n.string(.readerOptionsTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.string(.readerDone)) { coordinator.finishCustomizing() }
                }
            }
        }
        // Half height so the page stays visible, and interactive at that height so it stays
        // scrollable. `.large` is still offered for anyone using a large Dynamic Type size, where
        // three rows and a swatch strip no longer fit in half a screen. Both are no-ops on macOS,
        // where the sheet is a panel and the window behind it is visible anyway.
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    // MARK: Preview

    /// The live sample — see the note at the top on why it exists.
    private var previewSection: some View {
        Section {
            VerseSample(showsNumber: settings.showsVerseNumbers)
                .environment(\.readingStyle, settings.style(on: theme))
        } header: {
            Text(l10n.string(.readerPreviewSection))
        }
    }

    // MARK: Paper

    private var paperSection: some View {
        Section {
            HStack(spacing: 16) {
                ForEach(ReaderPaper.allCases) { paper in
                    swatch(paper)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        } header: {
            Text(l10n.string(.readerPaperSection))
        }
    }

    /// One paper, drawn as a scrap of the page it produces.
    ///
    /// The same argument `AccentSwatchRow` makes: a picker listing three colour *names* would ask
    /// the reader to imagine the result. This shows the background and the ink together, which is
    /// the pairing being chosen — and it carries no text inside the swatch, so nothing in it has
    /// to be translated or mirrored.
    private func swatch(_ paper: ReaderPaper) -> some View {
        let palette = theme.reading(paper)
        let isSelected = settings.paper == paper

        return Button {
            settings.select(paper: paper)
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(palette.background)
                    .frame(width: 56, height: 44)
                    .overlay { pageLines(palette) }
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .strokeBorder(
                                isSelected ? theme.textPrimary : theme.separator,
                                lineWidth: isSelected ? 2 : 1
                            )
                    }

                Text(l10n.string(paper.labelKey))
                    .appFont(.caption)
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
            }
        }
        // Plain, or every swatch would be tinted with the current accent and the papers would
        // stop being distinguishable — `AccentSwatchRow`'s problem exactly.
        .buttonStyle(.plain)
        .accessibilityLabel(l10n.string(paper.labelKey))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Three ruled lines, so a swatch reads as a page rather than a colour chip.
    private func pageLines(_ palette: ReadingPalette) -> some View {
        VStack(alignment: .trailing, spacing: 5) {
            ForEach([1.0, 0.78, 0.5], id: \.self) { fraction in
                Capsule()
                    .fill(palette.textPrimary)
                    .frame(width: 32 * fraction, height: 3)
            }
        }
        // Trailing-aligned and right-to-left, because the page these stand for is Arabic
        // whichever language the interface is in.
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityHidden(true)
    }

    // MARK: Font

    /// The two faces side by side, each setting the basmala in itself.
    ///
    /// Cards rather than a picker of names for `AccentSwatchRow`'s reason: "Madinah Mushaf" and
    /// "Amiri" ask the reader to already know what the faces look like, and the difference between
    /// them — the weight of the stroke, how high the marks stack — is only visible in the letters.
    private var fontSection: some View {
        Section {
            HStack(spacing: AppSpacing.md) {
                ForEach(ReaderFont.allCases) { face in
                    FontCard(
                        face: face,
                        isSelected: settings.font == face,
                        select: { settings.select(font: face) }
                    )
                }
            }
            .padding(.vertical, AppSpacing.xs)
        } header: {
            Text(l10n.string(.readerFontSection))
        }
    }

    // MARK: Verse numbers

    /// All twelve medallions in a row, each drawing the same number so only the ornament differs.
    private var markerSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(AyahMarkerStyle.allCases) { style in
                        MarkerSwatch(
                            style: style,
                            isSelected: settings.markerStyle == style,
                            select: { settings.select(markerStyle: style) }
                        )
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
            // Right to left like the page, so the first style sits where a reader of the verses
            // starts looking.
            .environment(\.layoutDirection, .rightToLeft)
        } header: {
            Text(l10n.string(.readerMarkerSection))
        }
    }

    // MARK: Text

    private var textSection: some View {
        Section {
            Stepper(
                value: textSize,
                in: ReaderTypography.textSizeRange,
                step: ReaderTypography.textSizeStep
            ) {
                measurementLabel(.readerTextSize, value: settings.typography.textSize)
            }

            Stepper(
                value: lineSpacing,
                in: ReaderTypography.lineSpacingRange,
                step: ReaderTypography.lineSpacingStep
            ) {
                measurementLabel(.readerLineSpacing, value: settings.typography.lineSpacing)
            }
        } header: {
            Text(l10n.string(.readerTextSection))
        }
    }

    // MARK: The page

    /// The two switches that change what is on the page rather than how it is set.
    ///
    /// Under the type section rather than in it, because neither is a measurement: one adds a
    /// mark to the text and the other is about the device. Grouping them with the steppers would
    /// say they were more of the same.
    private var pageSection: some View {
        Section {
            Toggle(isOn: verseNumbers) {
                Text(l10n.string(.readerShowVerseNumbers))
                    .foregroundStyle(theme.textPrimary)
            }

            Toggle(isOn: screenAwake) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(l10n.string(.readerKeepScreenAwake))
                        .foregroundStyle(theme.textPrimary)

                    // The cost, said on the row rather than discovered later. A switch that
                    // drains a battery without mentioning it is a switch nobody can consent to.
                    Text(l10n.string(.readerKeepScreenAwakeDetail))
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        } header: {
            Text(l10n.string(.readerPageSection))
        }
    }

    /// A name and the number in effect, in the reader's own digits — through `LocalizationManager`
    /// rather than interpolation, like every other number in the app. Rounded to an `Int` because
    /// both steps are whole points and "20.0" is noise.
    private func measurementLabel(_ titleKey: L10nKey, value: Double) -> some View {
        LabeledContent {
            Text(l10n.string(Int(value.rounded()), grouped: false))
                .appFont(.body)
                .foregroundStyle(theme.textSecondary)
        } label: {
            Text(l10n.string(titleKey))
                .foregroundStyle(theme.textPrimary)
        }
    }

    // MARK: Reset

    private var resetSection: some View {
        Section {
            Button {
                settings.reset()
            } label: {
                // Coloured by whether it will do anything. An explicit `foregroundStyle` wins
                // over the dimming `.disabled(_:)` would otherwise apply, so without this the
                // row reads as tappable on the way *in* — before the reader has chosen
                // anything — which is exactly when it does nothing.
                Text(l10n.string(.readerReset))
                    .foregroundStyle(settings.hasChoices ? theme.accent : theme.textSecondary)
            }
            // Disabled rather than hidden, so the row does not appear and disappear under the
            // reader's finger as they change things — `TipsSettingsSection`'s reasoning.
            .disabled(!settings.hasChoices)
        }
    }

    // MARK: Bindings

    /// `ReaderSettings` exposes its values `private(set)` and takes edits through methods, as
    /// `ThemeManager` does — so the two-way bindings a `Stepper` needs are made here rather than
    /// by loosening the manager. Each one reads the live value and routes the write through the
    /// method that clamps and persists it.
    private var textSize: Binding<Double> {
        Binding(
            get: { settings.typography.textSize },
            set: { settings.select(textSize: $0) }
        )
    }

    private var lineSpacing: Binding<Double> {
        Binding(
            get: { settings.typography.lineSpacing },
            set: { settings.select(lineSpacing: $0) }
        )
    }

    private var verseNumbers: Binding<Bool> {
        Binding(
            get: { settings.showsVerseNumbers },
            set: { settings.select(showsVerseNumbers: $0) }
        )
    }

    private var screenAwake: Binding<Bool> {
        Binding(
            get: { settings.keepsScreenAwake },
            set: { settings.select(keepsScreenAwake: $0) }
        )
    }
}

/// One verse, drawn exactly as `VerseRow` draws it: the reading face, the medallion, the paper.
private struct VerseSample: View {
    let showsNumber: Bool

    @Environment(\.readingStyle) private var style
    @ScaledMetric(relativeTo: .title3) private var typeScale: CGFloat = 1

    /// 112:1, verbatim from the corpus's Uthmani text. Hardcoded because the panel has no
    /// repository to read it through and does not need one for a single line.
    private static let words = "قُلْ هُوَ ٱللَّهُ أَحَدٌ"

    var body: some View {
        Text(AyahTextBuilder.text(
            Self.words,
            number: showsNumber ? 1 : nil,
            markerFont: style.markerStyle.font(
                size: style.typography.textSize * Double(typeScale) * AyahMarkerStyle.scale
            )
        ))
        .readingFont(size: style.typography.textSize, extraLineSpacing: style.typography.lineSpacing)
        .foregroundStyle(style.palette.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .listRowBackground(style.palette.background)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, AppLanguage.arabic.locale)
    }
}

/// One face, shown by setting the basmala in it.
private struct FontCard: View {
    let face: ReaderFont
    let isSelected: Bool
    let select: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private static let basmala = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"

    var body: some View {
        Button(action: select) {
            VStack(spacing: AppSpacing.sm) {
                Text(verbatim: Self.basmala)
                    .font(face.font(size: 20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .rightToLeft)
                    .accessibilityHidden(true)

                Text(l10n.string(face.labelKey))
                    .appFont(.caption, weight: isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? theme.accent.opacity(0.1) : .clear,
                in: .rect(cornerRadius: AppRadius.md)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(
                        isSelected ? theme.accent : theme.separator,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(.rect)
        }
        // Plain, or the whole card would be tinted with the accent and the two faces would stop
        // being comparable.
        .buttonStyle(.plain)
        .accessibilityLabel(l10n.string(face.labelKey))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// One medallion style, drawn around the same number as all the others.
private struct MarkerSwatch: View {
    let style: AyahMarkerStyle
    let isSelected: Bool
    let select: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: select) {
            // ASCII "7" because the face draws the medallion by a ligature over ASCII digits —
            // see `AyahTextBuilder`, which carries the same exception to the numbers rule.
            Text(verbatim: "7")
                .font(style.font(size: 30))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 52, height: 52)
                .background(
                    isSelected ? theme.accent.opacity(0.12) : .clear,
                    in: .circle
                )
                .overlay {
                    Circle().strokeBorder(
                        isSelected ? theme.accent : .clear,
                        lineWidth: 2
                    )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(l10n.string(.readerMarkerStyleLabel)) \(l10n.string(style.rawValue, grouped: false))"
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()
    FontRegistrar.registerBundledFonts()

    return ReaderSettingsSheet(
        settings: ReaderSettings(settingsStore: settingsStore),
        coordinator: QuranCoordinator()
    )
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}

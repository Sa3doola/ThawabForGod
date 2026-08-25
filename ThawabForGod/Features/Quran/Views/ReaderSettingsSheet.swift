//
//  ReaderSettingsSheet.swift
//  ThawabForGod
//

import SwiftUI

/// The reading panel: the page's colour, the size of the text, the space between its lines.
///
/// **There is no preview of the result in here, on purpose.** The panel opens at half height over
/// the page it is changing, and background interaction stays enabled — so the reader's own verses,
/// at their own size, are the preview, and they can go on scrolling them while they adjust. A
/// canned sample verse in a box would be a worse likeness of the thing sitting right above it, and
/// it would have meant a line of scripture hardcoded in a view.
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
                paperSection
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

#Preview {
    let settingsStore = InMemorySettingsStore()

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

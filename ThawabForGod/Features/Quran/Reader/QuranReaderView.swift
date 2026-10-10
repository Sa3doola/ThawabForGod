//
//  QuranReaderView.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran reader as a screen: the reading surface in either mode, with its toolbar, its bars
/// and its immersive mode around it.
///
/// **Nothing that changes while reading is read here** — not the Mushaf page, not the selection,
/// not the location. This view sits above the pager, and re-evaluating it on a page turn would
/// re-evaluate the pager's row of units (M4 measured what that costs). What it does read changes
/// at navigation rate: the load phase, the surah separated mode shows, the display mode, and the
/// chrome request. The title follows the same rule, so in Mushaf mode it is the section's name and
/// not the surah of the page, which the page prints for itself.
struct QuranReaderView: View {
    let viewModel: QuranReaderViewModel
    let coordinator: QuranCoordinator
    let faces: QuranFaces
    let services: MushafRenderServices

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverRunning
    /// True while this is the screen in front. The bars take the page's colours only then, so
    /// restoring them is something the code says rather than only something preference scoping
    /// implies.
    @State private var isOnScreen = false

    var body: some View {
        let palette = theme.reading(viewModel.settings.resolvedTheme(systemColorScheme: colorScheme))
        QuranReaderContent(viewModel: viewModel, faces: faces, services: services)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .quranReaderHidesSystemBack()
            .toolbar {
                QuranReaderToolbar(viewModel: viewModel, coordinator: coordinator, tint: palette.text)
            }
            .quranReaderBars(palette, isActive: isOnScreen && isReady)
            .quranImmersiveBars(hidden: isOnScreen && viewModel.isImmersive(voiceOverRunning: voiceOverRunning))
            .task { await viewModel.load() }
            // Hiding the system back button also removes VoiceOver's two-finger scrub, so give it back.
            .accessibilityAction(.escape) { coordinator.popToRoot() }
            .onChange(of: voiceOverRunning) { _, running in
                if running { viewModel.exitImmersive() }
            }
            .onAppear { isOnScreen = true }
            .onDisappear {
                isOnScreen = false
                viewModel.exitImmersive()
            }
    }

    private var isReady: Bool {
        if case .ready = viewModel.phase { true } else { false }
    }

    private var title: String {
        guard !viewModel.showsMushafPages, let surah = viewModel.corpus?.surah(viewModel.separatedSurah) else {
            return l10n.string(.quranTitle)
        }
        return surah.name(in: l10n.language)
    }
}

/// The `switch` over the load phase. Takes only what the surface needs, so it is built in a body
/// whose inputs a chrome toggle does not change. It observes the phase, the separated surah, the
/// scroll request and the display mode: the last so that a mode switch re-reads the unobserved
/// separated location.
private struct QuranReaderContent: View {
    let viewModel: QuranReaderViewModel
    let faces: QuranFaces
    let services: MushafRenderServices

    @Environment(\.theme) private var theme

    var body: some View {
        // Observed on purpose, though only its tracking is wanted: a switch from Mushaf to
        // separated within one surah changes neither the phase nor the surah, and this body must
        // still run so the surface is handed the location current at the switch.
        let _ = viewModel.showsMushafPages
        switch viewModel.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
                .accessibilityIdentifier("quran.reader.loading")
        case .failed:
            QuranLoadFailureView { await viewModel.retry() }
        case .ready(let corpus):
            QuranReadingSurface(
                corpus: corpus,
                settings: viewModel.settings,
                faces: faces,
                services: services,
                mushaf: viewModel.mushaf,
                separatedSurah: viewModel.separatedSurah,
                // The one untracked read. A list is created for three reasons: the surah changes,
                // the view tree is rebuilt, or the mode switches to separated. This body must be
                // re-evaluated for each, so each is an observed read here (`separatedSurah`, the
                // phase, `showsMushafPages`), and the value wanted is the one current then.
                separatedAyah: viewModel.separatedLocation,
                separatedScrollRequest: viewModel.separatedScrollRequest,
                onSelect: viewModel.select,
                onSeparatedTopAyahChange: viewModel.separatedTopAyahDidChange
            )
        }
    }
}

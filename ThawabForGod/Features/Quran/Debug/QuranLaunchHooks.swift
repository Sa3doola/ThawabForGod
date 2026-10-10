//
//  QuranLaunchHooks.swift
//  ThawabForGod
//

#if DEBUG
import SwiftUI

extension View {
    /// Applies the process's `QuranLaunchOptions` to the real reader: the scripted launches of the
    /// golden-page captures, the UI tests and the performance runs. **DEBUG only**, and a launch
    /// with no reader target does nothing at all.
    ///
    /// The *path* is the coordinator's (`AppContainer` pushes the reader for a scripted launch,
    /// with `openReader()`, which carries no target); the *place* goes straight to the view model
    /// here, once. It does not go through `QuranCoordinator.open(_:)` because the steps around it
    /// are ordered: the settings must be applied before the place, and the selection after it, so
    /// all of them run in one task.
    func quranLaunchHooks(
        viewModel: QuranReaderViewModel,
        container: AppContainer,
        options: QuranLaunchOptions = .current
    ) -> some View {
        modifier(QuranLaunchHooks(viewModel: viewModel, container: container, options: options))
    }
}

private struct QuranLaunchHooks: ViewModifier {
    let viewModel: QuranReaderViewModel
    let container: AppContainer
    let options: QuranLaunchOptions

    /// The options apply once per process, not every time the reader reappears.
    @MainActor private static var hasApplied = false

    func body(content: Content) -> some View {
        content
            .environment(\.forcedRenderer, options.renderer)
            .environment(\.foldOverride, options.foldOverride)
            .task { await apply() }
    }

    /// In this order, and in one task: the load first, so the options that are refused without
    /// capabilities (`-quranMode mushaf` on a build with no pages) are judged against what the
    /// database can draw rather than before it has said.
    private func apply() async {
        guard !Self.hasApplied, let target = options.readerTarget else { return }
        Self.hasApplied = true

        await viewModel.load()
        options.apply(to: container.quranReaderSettings)
        viewModel.open(target)
        // `.ayah` selects on arrival; the launch decides the selection itself, so a capture has a
        // band only when it asked for one.
        viewModel.mushaf.select(options.selectedAyah)
        if options.startsImmersive && DeviceKind.isPhone { viewModel.mushaf.isChromeHidden = true }

        guard let corpus = viewModel.corpus else { return }
        if let size = options.spreadRenderSize {
            await QuranSpreadRenderer.render(
                corpus: corpus, state: viewModel.mushaf, size: size, services: container.mushafRenderServices,
                faces: container.quranFaces, settings: container.quranReaderSettings, l10n: container.localizationManager,
                forced: options.renderer,
                palette: Theme.fallback.reading(container.quranReaderSettings.theme)
            )
        }
        if options.pagesThrough {
            let fonts = container.quranPageFonts
            let mushaf = viewModel.mushaf
            await PerformanceProbe.pageThrough(
                pageCount: corpus.style.pageCount,
                every: options.pageThroughEvery,
                registeredFonts: { fonts.registeredPages(style: corpus.style.id).count },
                show: { mushaf.show(page: $0) }
            )
        }
    }
}
#endif

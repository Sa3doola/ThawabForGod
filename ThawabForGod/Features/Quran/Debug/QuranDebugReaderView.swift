//
//  QuranDebugReaderView.swift
//  ThawabForGod
//

#if DEBUG
import SwiftUI

/// The ported renderer, reachable before the reader screen exists (M5): the reading surface on a
/// corpus loaded from the container, at a page or a surah. **DEBUG only** — the M4–M7 UI tests,
/// golden captures and performance runs drive it; a Release build has no trace of it.
///
/// Deliberately bare: no toolbar, panel or navigation of its own. What it shows is exactly what the
/// renderer draws, which is the point of a golden page.
struct QuranDebugReaderView: View {
    let container: AppContainer
    let target: QuranDebugTarget
    var options: QuranLaunchOptions = .current

    @State private var corpus: QuranCorpus?
    @State private var mushaf: MushafReadingState?
    @State private var separatedSurah = 1
    @State private var separatedAyah: VerseReference?
    @State private var failure: String?

    var body: some View {
        Group {
            if let corpus, let mushaf {
                QuranReadingSurface(
                    corpus: corpus,
                    settings: container.quranReaderSettings,
                    faces: container.quranFaces,
                    services: container.mushafRenderServices,
                    mushaf: mushaf,
                    separatedSurah: separatedSurah,
                    separatedAyah: separatedAyah,
                    onSelect: { mushaf.select(mushaf.selectedAyah == $0 ? nil : $0) }
                )
            } else if let failure {
                ContentUnavailableView(failure, systemImage: "exclamationmark.triangle")
            } else {
                ProgressView()
            }
        }
        .environment(\.forcedRenderer, options.renderer)
        .environment(\.foldOverride, options.foldOverride)
        .toolbarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard corpus == nil else { return }
        do {
            let repository = container.quranRepository
            container.quranReaderSettings.apply(try await repository.capabilities())
            let corpus = try await repository.loadCorpus(style: .madaniV2)
            let page: Int
            switch target {
            case .page(let number):
                page = number
                separatedSurah = corpus.page(number)?.firstAyah?.surah ?? 1
            case .surah(let surah, let ayah):
                let reference = VerseReference(surah: surah, verse: ayah ?? 1)
                page = corpus.pageNumber(for: reference) ?? 1
                separatedSurah = surah
                separatedAyah = reference
            }
            let state = MushafReadingState(page: page, pages: corpus.style.pages)
            state.select(options.selectedAyah)
            self.corpus = corpus
            mushaf = state
        } catch {
            failure = String(describing: error)
        }
    }
}

extension View {
    /// The DEBUG way into the renderer from the Quran tab's placeholder: two menu items, and the
    /// automatic open when the process was launched with a `-quranPage` or `-quranSurah` option.
    func quranDebugEntry(container: AppContainer) -> some View {
        modifier(QuranDebugEntry(container: container))
    }
}

private struct QuranDebugEntry: ViewModifier {
    let container: AppContainer

    @State private var target: QuranDebugTarget?
    @State private var prompt: Prompt?
    @State private var input = ""

    /// The launch options open the reader once per process, not every time the tab reappears.
    @MainActor private static var hasOpenedFromLaunch = false

    private enum Prompt: Identifiable {
        case page, surah
        var id: Self { self }
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem {
                    // Developer-facing, so `verbatim`: these never reach a Release build.
                    Menu {
                        Button { open(.page) } label: { Text(verbatim: "Open Mushaf page…") }
                        Button { open(.surah) } label: { Text(verbatim: "Open surah…") }
                    } label: {
                        Label { Text(verbatim: "Debug") } icon: { Image(systemName: "ladybug") }
                    }
                }
            }
            .alert(Text(verbatim: prompt == .page ? "Mushaf page (1–604)" : "Surah (1–114), optionally :ayah"), isPresented: isPrompting) {
                TextField(text: $input) { Text(verbatim: prompt == .page ? "50" : "2:255") }
                Button { submit() } label: { Text(verbatim: "Open") }
                Button(role: .cancel) {} label: { Text(verbatim: "Cancel") }
            }
            .navigationDestination(item: $target) { target in
                QuranDebugReaderView(container: container, target: target)
            }
            .task {
                guard !Self.hasOpenedFromLaunch, let launchTarget = QuranLaunchOptions.current.target else { return }
                Self.hasOpenedFromLaunch = true
                QuranLaunchOptions.current.apply(to: container.quranReaderSettings)
                target = launchTarget
            }
    }

    private var isPrompting: Binding<Bool> {
        Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })
    }

    private func open(_ kind: Prompt) {
        input = ""
        prompt = kind
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespaces)
        switch prompt {
        case .page:
            if let page = Int(normalizingDigits: text) { target = .page(page) }
        case .surah:
            if let reference = VerseReference(parsing: text) {
                target = .surah(reference.surah, ayah: reference.verse)
            } else if let surah = Int(normalizingDigits: text), (1...114).contains(surah) {
                target = .surah(surah, ayah: nil)
            }
        case nil:
            break
        }
        prompt = nil
    }
}
#endif

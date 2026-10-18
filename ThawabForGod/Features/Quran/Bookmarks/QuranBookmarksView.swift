//
//  QuranBookmarksView.swift
//  ThawabForGod
//

import SwiftUI

/// The reader's bookmarks, notes and highlights in one list: a segmented control picks the kind,
/// a menu picks the order. A tap opens the ayah in the reader; swipe or the context menu deletes,
/// and a note can be edited from the context menu. Ported from Mushaf's `BookmarksView`.
///
/// Shown as soon as the user data has loaded, whether or not the corpus has: without it a row is
/// its numeric reference only.
struct QuranBookmarksView: View {
    let viewModel: QuranBookmarksViewModel
    let coordinator: QuranCoordinator
    let settings: QuranReaderSettings

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.quranFaces) private var faces
    /// A note awaiting confirmation to be deleted.
    @State private var noteToDelete: QuranMarkRow?

    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = theme.reading(settings.resolvedTheme(systemColorScheme: colorScheme))
        content(palette)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(Text(l10n.string(viewModel.kind.titleKey)))
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                if viewModel.isLoaded { kindPicker(palette) }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) { orderMenu }
            }
            .task { await viewModel.prepare() }
            .sheet(item: $viewModel.editingNote) { editing in
                if let ayah = viewModel.corpus?.ayah(editing), let corpus = viewModel.corpus {
                    NoteEditorView(ayah: ayah, reference: reference(editing, corpus: corpus), userData: viewModel.userData)
                        .id(ayah.id)
                        .environment(\.readingPalette, palette)
                        .environment(\.quranFaces, faces)
                        .quranNoteEditorFrame()
                }
            }
            .confirmationDialog(
                l10n.string(.quranNoteDeleteConfirm),
                isPresented: Binding(get: { noteToDelete != nil }, set: { if !$0 { noteToDelete = nil } }),
                titleVisibility: .visible,
                presenting: noteToDelete
            ) { row in
                Button(l10n.string(.quranMarksDelete), role: .destructive) {
                    viewModel.delete(row)
                }
                Button(l10n.string(.cancelAction), role: .cancel) {}
            }
    }

    // MARK: Chrome

    private func kindPicker(_ palette: ReadingPalette) -> some View {
        @Bindable var viewModel = viewModel
        return Picker(l10n.string(.quranMarksShow), selection: $viewModel.kind) {
            ForEach(QuranMarkKind.allCases) { kind in
                Text(l10n.string(kind.titleKey)).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(palette.background)
        .accessibilityIdentifier("quran.bookmarks.kind")
    }

    private var orderMenu: some View {
        @Bindable var viewModel = viewModel
        return Menu {
            Picker(l10n.string(.quranMarksSort), selection: $viewModel.order) {
                ForEach(QuranMarkOrder.allCases) { order in
                    Text(l10n.string(order.titleKey)).tag(order)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(l10n.string(.quranMarksSort), systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("quran.bookmarks.order")
    }

    // MARK: States

    @ViewBuilder
    private func content(_ palette: ReadingPalette) -> some View {
        if viewModel.isLoaded {
            let sections = viewModel.sections
            List {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            rowButton(row, palette: palette)
                        }
                    } header: {
                        if section.surah > 0 { header(section.surah, palette: palette) }
                    }
                }
            }
            .accessibilityIdentifier("quran.bookmarks.list")
            .overlay {
                if sections.isEmpty { empty(palette) }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func empty(_ palette: ReadingPalette) -> some View {
        ContentUnavailableView {
            Label { Text(l10n.string(viewModel.kind.emptyKey)) } icon: { Image(systemName: viewModel.kind.systemImage) }
        } description: {
            Text(l10n.string(.quranMarksEmptyHint))
        }
        .foregroundStyle(palette.secondaryText)
        .accessibilityIdentifier("quran.bookmarks.empty")
    }

    /// "2. Al-Baqara", or just the number while the corpus is not loaded.
    private func header(_ surah: Int, palette: ReadingPalette) -> some View {
        let number = l10n.string(surah, grouped: false)
        let name = viewModel.corpus?.surah(surah)?.name(in: l10n.language)
        return Text(verbatim: name.map { "\(number). \($0)" } ?? number)
            .foregroundStyle(palette.secondaryText)
    }

    // MARK: Rows

    private func rowButton(_ row: QuranMarkRow, palette: ReadingPalette) -> some View {
        let corpus = viewModel.corpus
        let ayah = corpus?.ayah(row.ayah)
        return Button {
            coordinator.open(.ayah(row.ayah))
        } label: {
            QuranMarkRowView(
                row: row,
                reference: reference(row.ayah, corpus: corpus),
                ayahText: ayah?.text,
                dateText: viewModel.order == .date ? l10n.shortDateString(row.date) : nil,
                palette: palette
            )
        }
        .tint(palette.text)
        .listRowBackground(palette.background)
        .swipeActions(edge: .trailing, allowsFullSwipe: viewModel.kind != .notes) {
            // A notes delete asks first, and a destructive role would animate the row out before
            // the answer: Cancel would leave the row gone from the list while the data is intact.
            Button(role: viewModel.kind == .notes ? nil : .destructive) {
                requestDelete(row)
            } label: {
                Label(l10n.string(.quranMarksDelete), systemImage: "trash")
            }
        }
        .contextMenu {
            if viewModel.kind == .notes, ayah != nil {
                Button {
                    viewModel.editingNote = row.ayah
                } label: {
                    Label(l10n.string(.quranNoteEdit), systemImage: "square.and.pencil")
                }
            }
            Button(role: .destructive) {
                requestDelete(row)
            } label: {
                Label(l10n.string(.quranMarksDelete), systemImage: "trash")
            }
        }
    }

    /// Notes are the reader's own writing, so they ask first; bookmarks and highlights do not.
    private func requestDelete(_ row: QuranMarkRow) {
        if viewModel.kind == .notes {
            noteToDelete = row
        } else {
            viewModel.delete(row)
        }
    }

    /// One string, so the colon between the numbers cannot be reordered around them. Just `s:a`
    /// when the corpus is missing.
    private func reference(_ ref: VerseReference, corpus: QuranCorpus?) -> String {
        let numbers = "\(l10n.string(ref.surah, grouped: false)):\(l10n.string(ref.verse, grouped: false))"
        guard let name = corpus?.surah(ref.surah)?.name(in: l10n.language) else { return numbers }
        return "\(name) \(numbers)"
    }
}

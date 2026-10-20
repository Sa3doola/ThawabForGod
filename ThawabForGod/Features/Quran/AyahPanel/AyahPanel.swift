//
//  AyahPanel.swift
//  ThawabForGod
//

import SwiftUI

/// Everything about one ayah: the Hafs text at a compact size, Copy and Share, then a section picker
/// ("Translation | Tafsir") and the chosen section. A sheet on iPhone and iPad portrait, an
/// side panel on iPad landscape and the Mac.
///
/// Ported from Mushaf's `AyahPanel`, minus bookmark, note and highlight (M6). It reads the ayah from
/// the coordinator and the words from the reader's corpus, and **never calls a repository**: loading
/// is `AyahPanelViewModel`'s, awaited from the one `.task(id:)` below.
///
/// At the sheet's medium detent the Arabic is capped at about four lines, faded, with a button that
/// raises the sheet, so the first lines of the translation stay visible on a small phone.
struct AyahPanel: View {
    let coordinator: QuranCoordinator
    let panel: AyahPanelViewModel
    let reader: QuranReaderViewModel
    let userData: QuranUserDataStore
    /// Shown in a side panel: no toolbar (previous / next / Close sit above the Arabic instead).
    let isInspector: Bool

    @Environment(\.readingPalette) private var palette
    @State private var detent: PresentationDetent = .medium

    /// Nothing in this view may push a destination: in the side panel it has no stack of its own,
    /// so a `NavigationLink` would land on the reader's. "Read more" is a sheet; keep it that way.
    var body: some View {
        // The sheet wants a bar for its title and Done. The side panel sits inside the reader's own
        // stack, where a second `NavigationStack` makes the column pop the reader (B2), so it gets
        // the content bare and shows the reference in its stepper row instead.
        if isInspector {
            content.accessibilityIdentifier("quran.panel")
        } else {
            NavigationStack { content }
                .presentationDetents([.medium, .large], selection: $detent)
                .accessibilityIdentifier("quran.panel")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let id = coordinator.panelAyah, let ayah = reader.corpus?.ayah(id), let corpus = reader.corpus {
            AyahPanelContent(
                ayah: ayah, corpus: corpus, coordinator: coordinator, panel: panel, userData: userData,
                isInspector: isInspector, detent: $detent
            )
        } else {
            palette.background
        }
    }
}

/// The sheet's navigation title. Not applied in the side panel: with no stack of its own, a title
/// there would land on the reader's.
private struct PanelTitle: ViewModifier {
    let reference: String
    let applies: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if applies {
            content
                .navigationTitle(Text(verbatim: reference))
                .toolbarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

/// The panel once there is an ayah to show.
private struct AyahPanelContent: View {
    let ayah: Ayah
    let corpus: QuranCorpus
    let coordinator: QuranCoordinator
    let panel: AyahPanelViewModel
    let userData: QuranUserDataStore
    let isInspector: Bool
    @Binding var detent: PresentationDetent

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.quranFaces) private var faces
    @Environment(\.readingPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The Arabic size in the panel: fixed, independent of the reader's text size setting, but
    /// scaled with Dynamic Type. Compact in a sheet; larger in the side panel, which has the height.
    @ScaledMetric(relativeTo: .title3) private var sheetArabicSize: CGFloat = 18
    @ScaledMetric(relativeTo: .title3) private var inspectorArabicSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var translationSize: CGFloat = 17

    @State private var didCopy = false
    /// Height of the whole Arabic text, to know whether the medium-detent cap hides some of it.
    @State private var arabicHeight: CGFloat = 0
    /// One line of the Arabic. Measured here and kept, never computed in `body`.
    @State private var arabicLineHeight: CGFloat = 0

    private static let arabicLineSpacing: CGFloat = 2
    /// Lines of Arabic shown at the medium detent before the rest is faded out.
    private static let compactArabicLines: CGFloat = 4

    private struct LoadKey: Hashable {
        let ayah: VerseReference
        let tafsir: ContentPackID?
        let translations: [ContentPackID]
    }

    private var arabicSize: CGFloat { isInspector ? inspectorArabicSize : sheetArabicSize }
    private var language: AppLanguage { l10n.language }

    var body: some View {
        @Bindable var coordinator = coordinator
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // A sheet has previous / next in its navigation bar; the side panel has no bar.
                if isInspector { stepper }
                arabic
                actions
                notePreview
                sections
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(palette.background)
        .modifier(PanelTitle(reference: reference, applies: !isInspector))
        .toolbar {
            if !isInspector {
                ToolbarItemGroup(placement: .navigation) {
                    stepButton(previous: true)
                    stepButton(previous: false)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.string(.doneAction)) { coordinator.closePanel() }
                        .accessibilityIdentifier("quran.panel.done")
                }
            }
        }
        .task(id: LoadKey(
            ayah: ayah.id, tafsir: panel.currentTafsir(language: language)?.id,
            translations: panel.enabledTranslations().map(\.id)
        )) {
            didCopy = false
            await panel.load(ayah: ayah.id, language: language)
        }
        .onChange(of: arabicSize, initial: true) { _, size in
            arabicLineHeight = TextMeasurer.lineHeight(of: faces.platformFont(.ayahText, size: size)) + Self.arabicLineSpacing
        }
        .sheet(item: $coordinator.noteEditorAyah) { editing in
            if let editedAyah = corpus.ayah(editing) {
                NoteEditorView(ayah: editedAyah, reference: reference, userData: userData)
                    // A new ayah is a new draft: the editor's text must not outlive the ayah it was for.
                    .id(editedAyah.id)
                    .environment(\.readingPalette, palette)
                    .environment(\.quranFaces, faces)
                    .quranNoteEditorFrame()
            }
        }
    }

    // MARK: Reference

    /// "Al-Baqarah 2:255", with digits per the numeral setting.
    private var reference: String {
        let name = corpus.surah(ayah.id.surah)?.name(in: language) ?? ""
        return "\(name) \(l10n.string(ayah.id.surah, grouped: false)):\(l10n.string(ayah.id.verse, grouped: false))"
    }

    // MARK: Arabic

    /// Capped only in a sheet at the medium detent; the large detent and the side panel show it all.
    private var capsArabic: Bool { !isInspector && detent == .medium }

    /// The words, a no-break space, then the marker: drawn the way the separated reader draws them.
    /// Only the drawing differs from `ayah.text`; copy and share use `ayah.text` itself.
    private var arabicText: AttributedString {
        let hafsIsRegistered = faces.contains(.ayahText)
        var text = QuranAyahText.attributed(
            ayah.text, face: .kfgqpcHafs, scaledSize: Double(arabicSize), hafsIsRegistered: hafsIsRegistered
        )
        guard !ayah.marker.isEmpty else { return text }
        var marker = AttributedString(ayah.marker)
        marker.font = hafsIsRegistered ? ReaderFont.kfgqpcHafs.font(size: Double(arabicSize)) : nil
        text.append(AttributedString("\u{00A0}"))
        text.append(marker)
        return text
    }

    private var arabic: some View {
        let cap = arabicLineHeight * Self.compactArabicLines
        let isClipped = capsArabic && cap > 0 && arabicHeight > cap + 1
        return Text(arabicText)
            .font(faces.font(.ayahText, size: arabicSize))
            .lineSpacing(Self.arabicLineSpacing)
            .foregroundStyle(palette.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { arabicHeight = $0 }
            .frame(maxHeight: capsArabic && cap > 0 ? cap : nil, alignment: .top)
            .clipped()
            .mask {
                if isClipped {
                    FadeMask(edge: .bottom, fadeFraction: 1 / Self.compactArabicLines)
                } else {
                    Rectangle()
                }
            }
            .overlay(alignment: .bottom) {
                if isClipped { showWholeButton }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .textSelection(.enabled)
            .accessibilityIdentifier("quran.panel.arabic")
    }

    private var showWholeButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .default) { detent = .large }
        } label: {
            Label {
                Text(l10n.string(.quranPanelShowWhole))
            } icon: {
                Image(systemName: "chevron.down")
            }
        }
        .buttonStyle(.panelSmall)
        .background(Capsule().fill(palette.background))
        .padding(.bottom, 2)
        .accessibilityIdentifier("quran.panel.showWhole")
    }

    // MARK: Navigation

    /// Previous / next ayah and Close in the side panel, above the Arabic.
    private var stepper: some View {
        HStack {
            Button { step(to: corpus.ayah(before: ayah.id)) } label: {
                Label {
                    Text(l10n.string(.quranPanelPreviousAyah))
                } icon: {
                    Image(systemName: "chevron.backward")
                }
                .labelStyle(.iconOnly)
            }
            .disabled(corpus.ayah(before: ayah.id) == nil)
            .accessibilityIdentifier("quran.panel.previous")
            Button { step(to: corpus.ayah(after: ayah.id)) } label: {
                Label {
                    Text(l10n.string(.quranPanelNextAyah))
                } icon: {
                    Image(systemName: "chevron.forward")
                }
                .labelStyle(.iconOnly)
            }
            .disabled(corpus.ayah(after: ayah.id) == nil)
            .accessibilityIdentifier("quran.panel.next")
            Text(verbatim: reference)
                .appFont(.subheadline, weight: .semibold)
                .lineLimit(1)
                .layoutPriority(-1)
            Spacer()
            Button { coordinator.closePanel() } label: {
                Text(l10n.string(.quranPanelClose))
            }
            .layoutPriority(1)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("quran.panel.close")
        }
        .buttonStyle(.panelPlain)
    }

    /// An arrow in the sheet's navigation bar; VoiceOver reads the label.
    private func stepButton(previous: Bool) -> some View {
        let target = previous ? corpus.ayah(before: ayah.id) : corpus.ayah(after: ayah.id)
        return Button { step(to: target) } label: {
            Label {
                if previous { Text(l10n.string(.quranPanelPreviousAyah)) } else { Text(l10n.string(.quranPanelNextAyah)) }
            } icon: {
                Image(systemName: previous ? "chevron.backward" : "chevron.forward")
            }
            .labelStyle(.iconOnly)
        }
        .disabled(target == nil)
        .accessibilityIdentifier(previous ? "quran.panel.previous" : "quran.panel.next")
    }

    private func step(to ayah: VerseReference?) {
        guard let ayah else { return }
        coordinator.stepPanel(to: ayah)
    }

    // MARK: Actions

    /// What Copy and Share give: `Ayah.text` unmodified, the reference, then each loaded translation.
    private var shareText: String {
        AyahShareText.make(
            ayahText: ayah.text,
            reference: reference,
            translations: panel.translations(for: ayah.id).map { (text: $0.document.plainText, packName: $0.pack.name(in: language)) }
        )
    }

    private var actions: some View {
        let text = shareText
        // Labels when they fit on one line (a small phone in Arabic is the tightest), icons otherwise.
        // The last resort scrolls, so it survives accessibility type sizes.
        return ViewThatFits(in: .horizontal) {
            actionButtons(text: text, labelStyle: .titleAndIcon)
            actionButtons(text: text, labelStyle: .iconOnly)
            ScrollView(.horizontal, showsIndicators: false) {
                actionButtons(text: text, labelStyle: .iconOnly)
            }
        }
        .buttonStyle(.panelAction)
        .sensoryFeedback(.success, trigger: didCopy) { _, copied in copied }
        .sensoryFeedback(.impact(weight: .light), trigger: userData.isBookmarked(ayah.id)) { _, isBookmarked in
            isBookmarked
        }
    }

    private func actionButtons(text: String, labelStyle: some LabelStyle) -> some View {
        let isBookmarked = userData.isBookmarked(ayah.id)
        let hasNote = userData.note(for: ayah.id) != nil
        let highlight = userData.highlight(for: ayah.id)
        return HStack(spacing: 8) {
            Button {
                Pasteboard.copy(text)
                didCopy = true
            } label: {
                Label {
                    if didCopy { Text(l10n.string(.quranPanelCopied)) } else { Text(l10n.string(.quranPanelCopy)) }
                } icon: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                }
            }
            .accessibilityIdentifier("quran.panel.copy")
            ShareLink(item: text) {
                Label {
                    Text(l10n.string(.quranPanelShare))
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .accessibilityIdentifier("quran.panel.share")
            Button {
                userData.toggleBookmark(ayah.id)
            } label: {
                Label {
                    if isBookmarked {
                        Text(l10n.string(.quranBookmarkRemove))
                    } else {
                        Text(l10n.string(.quranBookmarkAdd))
                    }
                } icon: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            .accessibilityIdentifier("quran.panel.bookmark")
            Button {
                coordinator.editNote(ayah.id)
            } label: {
                Label {
                    if hasNote {
                        Text(l10n.string(.quranNoteEdit))
                    } else {
                        Text(l10n.string(.quranNoteAdd))
                    }
                } icon: {
                    Image(systemName: hasNote ? "note.text" : "note.text.badge.plus")
                }
            }
            .accessibilityIdentifier("quran.panel.note")
            Menu {
                HighlightMenuItems(current: highlight) { userData.setHighlight($0, for: ayah.id) }
            } label: {
                Label {
                    Text(l10n.string(.quranHighlight))
                } icon: {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(highlight.map { palette.highlight($0) } ?? palette.divider)
                        .overlay { Circle().stroke(palette.ornament, lineWidth: 1) }
                }
            }
            .menuStyle(.button)
            .accessibilityIdentifier("quran.panel.highlight")
        }
        .labelStyle(labelStyle)
        .fixedSize()
    }

    /// The note, four lines at most. Tapping it edits.
    @ViewBuilder
    private var notePreview: some View {
        if let note = userData.note(for: ayah.id) {
            Button {
                coordinator.editNote(ayah.id)
            } label: {
                Text(verbatim: note.text)
                    .appFont(.body)
                    .foregroundStyle(palette.text)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(palette.divider.opacity(0.6), in: .rect(cornerRadius: 10))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quran.panel.notePreview")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var sections: some View {
        let available = panel.sections(language: language)
        if available.count > 1 { sectionHeader(available) }
        switch panel.shownSection(language: language) {
        case .tafsir:
            TafsirSection(phase: panel.tafsir, reference: reference, showsReader: tafsirReaderBinding)
        case .translation:
            ForEach(panel.translations(for: ayah.id)) { item in
                TranslationTextView(item: item, fontSize: translationSize)
            }
        case nil:
            EmptyView()
        }
    }

    private var tafsirReaderBinding: Binding<Bool> {
        Binding(get: { coordinator.isTafsirReaderPresented }, set: { coordinator.isTafsirReaderPresented = $0 })
    }

    /// "Translation | Tafsir", and beside it the tafsir menu when more than one is enabled: one row,
    /// so the text starts as high as possible at the medium detent.
    private func sectionHeader(_ available: [AyahPanelSection]) -> some View {
        HStack(spacing: 12) {
            sectionPicker(available)
                .fixedSize()
            if panel.shownSection(language: language) == .tafsir, panel.enabledTafsirs().count > 1,
               let current = panel.currentTafsir(language: language) {
                tafsirMenu(current)
            }
            Spacer(minLength: 0)
        }
    }

    private func sectionPicker(_ available: [AyahPanelSection]) -> some View {
        @Bindable var panel = panel
        return Picker(selection: $panel.requestedSection) {
            ForEach(available) { section in
                switch section {
                case .translation: Text(l10n.string(.quranPanelTranslation)).tag(section)
                case .tafsir: Text(l10n.string(.tafsirTitle)).tag(section)
                }
            }
        } label: {
            Text(l10n.string(.quranPanelSection))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("quran.panel.sectionPicker")
    }

    /// The shown tafsir's name, truncated in the middle so its start and its qualifier stay readable.
    /// Switching keeps the ayah.
    private func tafsirMenu(_ current: ContentPack) -> some View {
        @Bindable var panel = panel
        return Menu {
            Picker(selection: Binding(get: { current.id }, set: { panel.pickedTafsir = $0 })) {
                ForEach(panel.enabledTafsirs()) { pack in
                    Text(verbatim: pack.name(in: language)).tag(pack.id)
                }
            } label: {
                Text(l10n.string(.tafsirTitle))
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: current.name(in: language))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .appFont(.subheadline, weight: .medium)
            .foregroundStyle(palette.ornament)
            // A 44 pt target: the line of text alone is about 20 pt tall.
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityIdentifier("quran.panel.tafsirMenu")
    }
}

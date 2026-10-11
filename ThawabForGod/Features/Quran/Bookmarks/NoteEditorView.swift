//
//  NoteEditorView.swift
//  ThawabForGod
//

import SwiftUI

/// A plain-text note on one ayah. Save stores it (empty text removes the note), Delete removes it
/// after confirmation, Cancel leaves it as it was. Ported from Mushaf.
///
/// The ayah is drawn above the editor through `QuranAyahText` for context only; the editor never
/// stores Quran text, only what the reader types.
struct NoteEditorView: View {
    let ayah: Ayah
    let reference: String
    let userData: QuranUserDataStore

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.quranFaces) private var faces
    @Environment(\.readingPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var arabicSize: CGFloat = 18

    @State private var text = ""
    @State private var loaded = false
    @State private var confirmsDelete = false
    @FocusState private var isFocused: Bool

    private var existing: QuranNote? { userData.note(for: ayah.id) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(ayahText)
                    .font(faces.font(.ayahText, size: arabicSize))
                    .lineSpacing(2)
                    .lineLimit(3)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                TextEditor(text: $text)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(palette.divider.opacity(0.6), in: .rect(cornerRadius: 10))
                    .accessibilityLabel(Text(l10n.string(.quranNote)))
                    .accessibilityIdentifier("quran.note.editor")
                if existing != nil {
                    Button(role: .destructive) { confirmsDelete = true } label: {
                        Label {
                            Text(l10n.string(.quranNoteDelete))
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                    .accessibilityIdentifier("quran.note.delete")
                }
            }
            .padding()
            .background(palette.background)
            .navigationTitle(Text(verbatim: reference))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text(l10n.string(.cancelAction))
                    }
                    .accessibilityIdentifier("quran.note.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        userData.setNote(text, for: ayah.id)
                        dismiss()
                    } label: {
                        Text(l10n.string(.saveAction))
                    }
                    .accessibilityIdentifier("quran.note.save")
                }
            }
            .confirmationDialog(
                Text(l10n.string(.quranNoteDeleteConfirm)),
                isPresented: $confirmsDelete
            ) {
                Button(role: .destructive) {
                    userData.setNote("", for: ayah.id)
                    dismiss()
                } label: {
                    Text(l10n.string(.quranNoteDelete))
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                text = existing?.text ?? ""
                isFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Drawing only: the words and marker as the panel draws them. Nothing here is stored.
    private var ayahText: AttributedString {
        var attributed = QuranAyahText.attributed(
            ayah.text, face: .kfgqpcHafs, scaledSize: Double(arabicSize), hafsIsRegistered: faces.contains(.ayahText)
        )
        if !ayah.marker.isEmpty {
            attributed.append(AttributedString("\u{00A0}" + ayah.marker))
        }
        return attributed
    }
}

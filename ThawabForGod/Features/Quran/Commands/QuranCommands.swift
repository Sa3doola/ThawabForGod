//
//  QuranCommands.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran menu: the Mac menu bar, and the iPad ⌘ overlay. Every item acts on the focused
/// scene's `QuranCommandTarget`, which only the Quran section publishes and which checks that the
/// Quran is the selected section, so no shortcut here can reach another section.
struct QuranCommands: Commands {
    let localization: LocalizationManager

    @FocusedValue(\.quranCommandTarget) private var target

    var body: some Commands {
        // The system's Find items (Find…, Find Next) would take ⌘F and ⌘G, and Noor has no text to
        // find in; Search and Go to use those keys.
        CommandGroup(replacing: .textEditing) {}
        CommandMenu(localization.string(.quranTitle)) {
            ForEach(Array(QuranCommand.groups.enumerated()), id: \.offset) { index, group in
                if index > 0 { Divider() }
                ForEach(group) { command in
                    Button {
                        target?.perform(command)
                    } label: {
                        Label {
                            Text(localization.string(command.titleKey))
                        } icon: {
                            Image(systemName: command.systemImage)
                        }
                    }
                    .keyboardShortcut(command.shortcut)
                    .disabled(target?.isEnabled(command) != true)
                }
            }
        }
    }
}

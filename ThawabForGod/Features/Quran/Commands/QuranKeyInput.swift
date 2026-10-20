import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension View {
    /// The reader's hardware-keyboard glue. UIKit and AppKit hand the unmodified keys (←, →, Space,
    /// Page Up/Down) to the system before any menu or SwiftUI shortcut, so a small responder (iPad)
    /// or a local event monitor (Mac) runs the same `QuranCommand`s the Quran menu does. Every
    /// command still passes through `QuranCommandTarget.isEnabled`, so nothing fires when the Quran
    /// section is not the selected one. `isActive` is false while a sheet owns the keyboard.
    func quranReaderKeys(target: QuranCommandTarget, isActive: Bool) -> some View {
        #if os(iOS)
        background(
            QuranKeyResponder(target: target, isActive: isActive)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        )
        #elseif os(macOS)
        background(QuranKeyMonitorView(target: target, isActive: isActive))
            .background(QuranKeyAlternates(target: target))
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Binds every command's shortcut and alternates as title-less `UIKeyCommand`s on a first responder
/// consulted before the main menu. The Quran menu lists each command once in the ⌘ overlay.
private struct QuranKeyResponder: UIViewRepresentable {
    let target: QuranCommandTarget
    let isActive: Bool

    func makeUIView(context: Context) -> ResponderView {
        ResponderView()
    }

    func updateUIView(_ view: ResponderView, context: Context) {
        view.target = target
        view.isActive = isActive && target.isSectionActive()
        if view.isActive { view.claimFirstResponder() }
    }

    final class ResponderView: UIView {
        var target: QuranCommandTarget?
        var isActive = true

        override var canBecomeFirstResponder: Bool { isActive }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            claimFirstResponder()
        }

        func claimFirstResponder() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isActive, self.window != nil, !self.isFirstResponder else { return }
                self.becomeFirstResponder()
            }
        }

        override var keyCommands: [UIKeyCommand]? { Self.bindings }

        private static let bindings: [UIKeyCommand] = QuranCommand.allCases.flatMap { command in
            ([command.shortcut] + command.alternates).compactMap { shortcut -> UIKeyCommand? in
                guard let input = input(for: shortcut.key) else { return nil }
                let key = UIKeyCommand(
                    title: "", action: #selector(handle(_:)), input: input,
                    modifierFlags: flags(shortcut.modifiers), propertyList: command.rawValue
                )
                key.wantsPriorityOverSystemBehavior = true
                // A Mushaf pages right to left in every language: ← stays the next page in an
                // Arabic UI. Brackets keep the system's mirroring, like the menu.
                if [KeyEquivalent.leftArrow, .rightArrow].contains(shortcut.key) {
                    key.allowsAutomaticMirroring = false
                }
                return key
            }
        }

        @objc private func handle(_ key: UIKeyCommand) {
            guard let raw = key.propertyList as? String,
                  let command = QuranCommand(rawValue: raw),
                  let target, target.isEnabled(command)
            else { return }
            target.perform(command)
        }

        private static func input(for key: KeyEquivalent) -> String? {
            switch key {
            case .leftArrow: UIKeyCommand.inputLeftArrow
            case .rightArrow: UIKeyCommand.inputRightArrow
            case .pageUp: UIKeyCommand.inputPageUp
            case .pageDown: UIKeyCommand.inputPageDown
            case .space: " "
            default:
                key.character.isLetter || key.character.isPunctuation || key.character.isSymbol
                    ? String(key.character) : nil
            }
        }

        private static func flags(_ modifiers: EventModifiers) -> UIKeyModifierFlags {
            var flags: UIKeyModifierFlags = []
            if modifiers.contains(.shift) { flags.insert(.shift) }
            if modifiers.contains(.command) { flags.insert(.command) }
            if modifiers.contains(.option) { flags.insert(.alternate) }
            if modifiers.contains(.control) { flags.insert(.control) }
            return flags
        }
    }
}
#endif

#if os(macOS)
/// The keys a SwiftUI shortcut cannot carry on the Mac: Space and ⇧Space (a shortcut takes one for
/// the other), Page Up / Page Down, and ⌘[ / ⌘] (a `NavigationStack` claims them for Back and
/// Forward before the menu sees them). The plain arrows are here too: as menu key equivalents they
/// never fired while the reader's scroll view had focus (M8), so ← / → are handled before the menu.
/// A Mushaf pages right to left in every language, so ← is the next page whatever the UI language. Virtual key codes for the layout-independent keys,
/// characters for the brackets (their key differs between layouts).
private enum QuranMonitoredKey {
    static func command(for event: NSEvent) -> QuranCommand? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.function, .numericPad])
        switch (event.keyCode, modifiers) {
        case (49, []), (121, []), (123, []): return .nextPage      // Space, Page Down, ←
        case (49, [.shift]), (116, []), (124, []): return .previousPage  // ⇧Space, Page Up, →
        default: break
        }
        guard modifiers == [.command] else { return nil }
        // AppKit mirrors bracket shortcuts in a right-to-left UI (the Arabic menu shows Next
        // surah as ⌘[); the keys follow the menu.
        let mirrored = NSApp.userInterfaceLayoutDirection == .rightToLeft
        switch event.charactersIgnoringModifiers {
        case "[": return mirrored ? .nextSurah : .previousSurah
        case "]": return mirrored ? .previousSurah : .nextSurah
        default: return nil
        }
    }
}

/// Installs a local key monitor while the view is in a window. Ignores events of other windows,
/// a window showing a sheet, and any key while a text field is being edited.
private struct QuranKeyMonitorView: NSViewRepresentable {
    let target: QuranCommandTarget
    let isActive: Bool

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        view.target = target
        view.isActive = isActive
    }

    final class MonitorView: NSView {
        var target: QuranCommandTarget?
        var isActive = true
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.handle(event) else { return event }
                return nil
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        private func handle(_ event: NSEvent) -> Bool {
            guard isActive, target?.isSectionActive() == true, let target, let window, event.window === window, window.isKeyWindow,
                  window.attachedSheet == nil, !(window.firstResponder is NSText),
                  let command = QuranMonitoredKey.command(for: event), target.isEnabled(command)
            else { return false }
            target.perform(command)
            return true
        }
    }
}

/// ⌘= as a second way to enlarge text: a menu item carries one shortcut, so the alternate is a
/// hidden zero-size button in the reader's background.
private struct QuranKeyAlternates: View {
    let target: QuranCommandTarget

    var body: some View {
        ZStack {
            ForEach(QuranCommand.allCases.filter { !$0.alternates.isEmpty }) { command in
                ForEach(Array(command.alternates.enumerated()), id: \.offset) { _, shortcut in
                    // Space, ⇧Space and Page Up/Down are the monitor's; only plain character
                    // alternates (⌘=) belong here.
                    if shortcut.modifiers.contains(.command) {
                        Button("") { if target.isEnabled(command) { target.perform(command) } }
                            .keyboardShortcut(shortcut)
                            .disabled(!target.isEnabled(command))
                    }
                }
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}
#endif

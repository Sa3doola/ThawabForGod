//
//  ReminderArtwork.swift
//  ThawabForGod
//

import SwiftUI

/// The prayer's symbol on the prayer's own light, as a PNG a notification can carry.
///
/// A collapsed banner cannot be drawn by this app — iOS renders it, and the only thing it will
/// take from us beyond three lines of text is one attachment, shown as a thumbnail on the trailing
/// side. So the thumbnail is the whole of the banner's design, and it is worth making it say
/// something: the symbol identifies the prayer at a glance, and the `DayRamp` stop behind it puts
/// Fajr's blue and Maghrib's rose on the screen at the hour they belong to.
///
/// **Rendered, not bundled.** Six static PNGs would be six files that do not know the reader's
/// accent, and would have to be redrawn by hand every time the ramp moves. `ImageRenderer` over
/// the same `DayRampBackground` the widget and the Home card use means there is one drawing of a
/// prayer's light in this project, not three.
///
/// **Rendered once.** The render is cached in the App Group container under a name carrying the
/// prayer and the accent, so a refresh that schedules fifty reminders renders at most five images,
/// and the next refresh renders none.
///
/// **Copied per call**, which is the trap this type exists to absorb: `UNNotificationAttachment`
/// *moves* its file into the system's attachment store. Handing the cached file to fifty requests
/// would work once and fail silently forty-nine times, and the symptom — the first prayer of the
/// window having a picture and the rest not — is a hard one to go looking for. So every call
/// returns a fresh copy in the temporary directory; the cheap half repeats and the expensive half
/// does not.
@MainActor
struct ReminderArtwork: ReminderArtworkProviding {

    private let settingsStore: any SettingsStore
    private let fileManager: FileManager

    /// 256 points at 3× is a 768-pixel square — larger than any banner thumbnail iOS draws, and
    /// small enough that five of them cost nothing to keep.
    private let side: CGFloat = 256

    init(settingsStore: any SettingsStore, fileManager: FileManager = .default) {
        self.settingsStore = settingsStore
        self.fileManager = fileManager
    }

    func artwork(for prayer: Prayer) -> URL? {
        guard let cached = cachedImage(for: prayer) else { return nil }

        return copyForAttachment(cached)
    }

    // MARK: The cache

    private var accent: AccentPalette {
        settingsStore.string(for: .accentPalette)
            .flatMap(AccentPalette.init(rawValue:)) ?? .fallback
    }

    /// The rendered file, drawing it first if it is not there.
    ///
    /// Keyed on the accent as well as the prayer, so changing the accent does not silently go on
    /// serving the old one — and so the stale files of an accent the reader has moved off are
    /// five small PNGs rather than a leak worth managing.
    private func cachedImage(for prayer: Prayer) -> URL? {
        guard let directory = cacheDirectory() else { return nil }

        let url = directory.appendingPathComponent("\(prayer.rawValue)-\(accent.rawValue).png")

        if fileManager.fileExists(atPath: url.path) { return url }

        guard let data = render(prayer) else { return nil }

        return (try? data.write(to: url, options: .atomic)) == nil ? nil : url
    }

    /// Inside the App Group rather than the app's own Caches, so the container is the same one
    /// every other shared thing lives in and there is one place to look when a stale image is
    /// being served.
    private func cacheDirectory() -> URL? {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: SharedDefaults.groupIdentifier
        ) else {
            return nil
        }

        let directory = container.appendingPathComponent("ReminderArtwork", isDirectory: true)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        return fileManager.fileExists(atPath: directory.path) ? directory : nil
    }

    // MARK: Drawing

    private func render(_ prayer: Prayer) -> Data? {
        let renderer = ImageRenderer(content: ArtworkTile(prayer: prayer, accent: accent, side: side))

        // The banner shows this at a fraction of its size, so it is drawn at 3× and left to be
        // scaled down rather than rendered per device.
        renderer.scale = 3

        #if os(macOS)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
        #else
        return renderer.uiImage?.pngData()
        #endif
    }

    /// A fresh file for the caller to hand to `UNNotificationAttachment`, which will take it.
    ///
    /// A UUID in the name because two requests can be in flight in the same millisecond and the
    /// second one finding the first one's file already there would be a race for a picture.
    private func copyForAttachment(_ source: URL) -> URL? {
        let destination = fileManager.temporaryDirectory
            .appendingPathComponent("reminder-\(UUID().uuidString).png")

        do {
            try fileManager.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}

/// What gets drawn: the prayer's light, the lattice, and its symbol over both.
///
/// `DayRampBackground` rather than a flat colour, so the thumbnail is recognisably the same object
/// as the Home card and the widget behind it. Square, because a banner thumbnail is square and a
/// rectangle would be centre-cropped to one anyway.
private struct ArtworkTile: View {
    let prayer: Prayer
    let accent: AccentPalette
    let side: CGFloat

    var body: some View {
        // The ramp inverts the palette — see `Theme.onDayRamp` — which is what makes the symbol
        // legible over Dhuhr's amber as well as over Isha's near-black.
        let theme = Theme(accent: accent).onDayRamp

        return Image(systemName: prayer.symbol)
            .font(.system(size: side * 0.42))
            .foregroundStyle(theme.textPrimary)
            .frame(width: side, height: side)
            .background { DayRampBackground(stop: DayRamp.stop(for: prayer)) }
    }
}

//
//  QuranWidgetRenderTests.swift
//  ThawabForGodTests
//

import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import ThawabForGod

/// Draws every Quran widget family with `ImageRenderer` and writes the PNGs for a human to look at
/// (M8-B4, section 7). No WidgetKit is involved: the content views are drawn as the widget draws them.
///
/// For each profile (public, and full where the QUL data is built), for each reference in
/// `references`, each family and each language, the Ayah of the day and the Continue Reading content
/// are rendered at their widget sizes with the palette behind them and 16 points of padding. Every
/// image must come out non-nil, and the Hafs face must have registered: a render without it draws
/// the system face, and the PNG would look right while being wrong.
///
/// The PNGs go to `Screenshots/quran-migration/M8/widgets/` at the repository root, which is
/// git-ignored. The folder is created here; if a file cannot be written the test still passes,
/// because the image is what is under test and the folder is only a convenience to look at.
@MainActor
struct QuranWidgetRenderTests {

    /// The four references the widgets are checked against: a single ayah, a short surah's first
    /// verse, a four-verse range, and the ayah that carries a translation's longest line.
    private static let references: [(name: String, surah: Int, first: Int, last: Int)] = [
        ("1-1-7", 1, 1, 7),
        ("2-255", 2, 255, 255),
        ("112-1-4", 112, 1, 4),
        ("25-63", 25, 63, 63),
    ]

    private static let languages: [(code: String, language: AppLanguage, digits: NumberSystem)] = [
        ("en", .english, .latin),
        ("ar", .arabic, .arabicIndic),
    ]

    // MARK: Profiles

    /// The public (Tanzil) database, which every clone carries.
    @Test func publicProfileRendersEveryFamily() async throws {
        try await renderEveryFamily(database: QuranTestData.publicDatabase, profile: "public")
    }

    /// The full (QUL) database, where it was built. Its translations are the bundled Saheeh pack.
    @Test(.enabled(if: QuranTestData.hasFullData, QuranTestData.fullDataReason))
    func fullProfileRendersEveryFamily() async throws {
        try await renderEveryFamily(database: QuranTestData.fullDatabase, profile: "full")
    }

    // MARK: Memory (B16)

    /// One large render of the longest reference, measured as the process's footprint before and
    /// after: the face registered, the stored snapshot decoded and trimmed as the timeline does, and
    /// the content drawn at 3x. A widget extension is killed at about 30 MB; this is a simulator
    /// figure for the test process (so it includes nothing of the extension's own baseline),
    /// bounded at half the budget (the run that closed B16 measured about 1.2 MB, 10 of 125 entries kept).
    @Test func oneLargeRenderStaysWellInsideTheExtensionBudget() async throws {
        let harness = QuranWidgetHarness(database: QuranTestData.publicDatabase, packs: QuranTestData.bundledPacks)
        await harness.publish()
        let json = try #require(harness.snapshot().flatMap { try? JSONEncoder().encode($0) })
        let fonts = try Self.fontFolder()
        defer { try? FileManager.default.removeItem(at: fonts) }

        let before = Self.footprint()
        let hasHafs = QuranWidgetFontRegistration.register(folder: fonts)
        let decoded = try JSONDecoder().decode(QuranWidgetSnapshot.self, from: json)
        let now = harness.clock.now
        let held = decoded.trimmed(from: now, days: 8)
        let style = NextPrayerSnapshot.Style(numberSystem: .latin, clockFormat: .fallback, accent: .fallback, language: .english)
        let entry = QuranWidgetEntry(date: now, snapshot: held, style: style, hasHafs: hasHafs)
        let image = Self.image(
            QuranAyahOfTheDayContent(entry: entry, family: .large).quranWidgetTheme(style: style),
            family: .large, style: style)
        let delta = Self.footprint() - before
        #expect(image != nil)
        #expect(delta < 15 * 1024 * 1024)
    }

    private static func footprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }

    // MARK: Rendering

    private func renderEveryFamily(database: QuranDatabase, profile: String) async throws {
        let harness = QuranWidgetHarness(database: database, packs: QuranTestData.bundledPacks)
        await harness.publish()
        let snapshot = try #require(harness.snapshot())
        let surahs = try await harness.repository.surahs(style: MushafStyle.madaniV2.id)

        let fonts = try Self.fontFolder()
        defer { try? FileManager.default.removeItem(at: fonts) }
        let hasHafs = QuranWidgetFontRegistration.register(folder: fonts)
        #expect(hasHafs, "the Hafs face registers in the widget process")

        for reference in Self.references {
            let target = try #require(snapshot.entries.first {
                $0.first == VerseReference(surah: reference.surah, verse: reference.first) && $0.lastVerse == reference.last
            }, "the list has \(reference.name)")
            let day = try #require(Self.day(showing: target, in: snapshot, from: harness.clock.now))
            let surah = try #require(surahs.first { $0.number == reference.surah })

            for language in Self.languages {
                let style = NextPrayerSnapshot.Style(
                    numberSystem: language.digits, clockFormat: .fallback, accent: .fallback, language: language.language
                )
                var continuing = snapshot
                continuing.continueReading = QuranWidgetSnapshot.ContinueReading(
                    ayah: VerseReference(surah: reference.surah, verse: reference.first),
                    surahNameArabic: surah.arabicName, surahNameEnglish: surah.englishName, page: nil, juz: nil
                )

                for family in QuranWidgetFamily.allCases {
                    let ayahEntry = QuranWidgetEntry(date: day, snapshot: snapshot, style: style, hasHafs: hasHafs)
                    let ayah = Self.image(
                        QuranAyahOfTheDayContent(entry: ayahEntry, family: family).quranWidgetTheme(style: style),
                        family: family, style: style
                    )
                    let continueEntry = QuranWidgetEntry(date: day, snapshot: continuing, style: style, hasHafs: hasHafs)
                    let continueImage = Self.image(
                        QuranContinueReadingContent(entry: continueEntry, family: family).quranWidgetTheme(style: style),
                        family: family, style: style
                    )

                    let base = "\(family)-\(reference.name)-\(language.code)-\(profile).png"
                    #expect(ayah != nil, "ayah \(base)")
                    #expect(continueImage != nil, "continue \(base)")
                    if let ayah { Self.writePNG(ayah, named: "ayah-\(base)") }
                    if let continueImage { Self.writePNG(continueImage, named: "continue-\(base)") }
                }
            }
        }
    }

    /// The widget's frame, with the padding and the palette behind it, at three times the point size.
    private static func image<Content: View>(
        _ content: Content, family: QuranWidgetFamily, style: NextPrayerSnapshot.Style
    ) -> CGImage? {
        let size = size(of: family)
        let framed = content
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(Theme(accent: style.accent).background)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 3
        return renderer.cgImage
    }

    private static func size(of family: QuranWidgetFamily) -> CGSize {
        switch family {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        case .rectangular: CGSize(width: 172, height: 76)
        }
    }

    /// The first day from `now` on which the day rule names the target's entry, so the widget draws
    /// that entry the way it would on that day.
    private static func day(showing target: QuranWidgetSnapshot.DailyAyah, in snapshot: QuranWidgetSnapshot, from now: Date) -> Date? {
        let calendar = DailyAyahRule.calendar
        for offset in 0..<max(snapshot.listCount, 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            if DailyAyahRule.entryIndex(for: date, count: snapshot.listCount, calendar: calendar) == target.index {
                return date
            }
        }
        return nil
    }

    // MARK: Files

    /// `Screenshots/quran-migration/M8/widgets/`, found from this file's path: Widgets, then
    /// ThawabForGodTests, then the repository root.
    private static var outputFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Screenshots/quran-migration/M8/widgets", isDirectory: true)
    }

    /// A folder holding the Hafs and Amiri faces, as the App Group container does in the app.
    private static func fontFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("QuranWidgetFonts-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let root = try #require(Bundle.main.resourceURL)
        for fileName in [QuranWidgetFont.fileName, QuranWidgetFont.amiriFileName] {
            let base = (fileName as NSString).deletingPathExtension
            let source = try #require(
                Bundle.main.url(forResource: base, withExtension: "ttf")
                    ?? FontRegistrar.fontURLs(under: root).first { $0.lastPathComponent == fileName }
            )
            try FileManager.default.copyItem(at: source, to: folder.appendingPathComponent(fileName))
        }
        return folder
    }

    /// Best effort: a folder that cannot be created or a file that cannot be written is not a failure.
    private static func writePNG(_ image: CGImage, named name: String) {
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(
            outputFolder.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        _ = CGImageDestinationFinalize(destination)
    }
}

import Foundation
import QuranDataModel

/// `data/ayah-of-the-day.txt` → the JSON the app will bundle (references only; the text comes
/// from the database).
/// Every entry is checked against the ayahs just built; any problem fails the build.
func buildAyahOfTheDay(_ curated: BuildConfig.Curated, config: BuildConfig, ayahCounts: [Int]) throws -> CuratedAyahList.Output {
    let source = config.path(curated.ayahOfTheDay)
    let text = try String(contentsOf: source, encoding: .utf8)
    let entries = try CuratedAyahList.parse(text)

    let problems = CuratedAyahList.problems(entries, ayahCounts: ayahCounts, minimumCount: curated.minimumEntries)
    try require(problems.isEmpty, "ayah of the day: " + problems.joined(separator: "; "))

    let output = CuratedAyahList.Output(
        source: "Tools/QuranBuilder/data/" + source.lastPathComponent,
        sha256: try SourceManifest.sha256(of: source),
        status: CuratedAyahList.status(text),
        entries: entries
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let destination = config.path(curated.ayahOfTheDayOutput)
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoder.encode(output).write(to: destination, options: .atomic)
    return output
}

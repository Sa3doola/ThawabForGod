import Foundation

/// Copies a finished build into the app target's resources (`BuildConfig.Install`, T4): the
/// database, every pack the profile wrote and, for qul, the three QUL faces. Runs last, after every
/// check and the size budget have passed, so a failed build never replaces what the app has.
///
/// The tanzil copies are committed and the qul ones are git-ignored by name; the page fonts are not
/// copied at all, because the qul profile already writes them into the folder the app references.
func installOutputs(_ config: BuildConfig) throws -> [URL] {
    guard let install = config.install else { return [] }
    var installed: [URL] = []

    installed.append(try replace(config.path(install.database), with: config.path(config.output)))

    if let packsDestination = install.packs, let packs = config.packs {
        let built = config.path(packs.directory)
        for file in try contents(of: built) where file.hasSuffix(".sqlite") {
            installed.append(try replace(config.path(packsDestination).appendingPathComponent(file),
                                         with: built.appendingPathComponent(file)))
        }
    }

    if let fontsDestination = install.fonts, let qul = config.qul {
        let built = config.path(qul.fonts.bundleDirectory)
        for file in try contents(of: built) where file.hasSuffix(".ttf") {
            installed.append(try replace(config.path(fontsDestination).appendingPathComponent(file),
                                         with: built.appendingPathComponent(file)))
        }
    }

    if let listDestination = install.ayahOfTheDay, let curated = config.curated {
        installed.append(try replace(config.path(listDestination), with: config.path(curated.ayahOfTheDayOutput)))
    }
    return installed
}

private func contents(of folder: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }.sorted()
}

private func replace(_ destination: URL, with source: URL) throws -> URL {
    let manager = FileManager.default
    try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
    try manager.copyItem(at: source, to: destination)
    return destination
}

//
//  QuranReadingPositionRecording.swift
//  ThawabForGod
//

/// What the reader needs from the store that keeps its place: say where it is, and wait until that
/// has reached the disk. A protocol so the reader's view model can run with none (tests, previews).
@MainActor
protocol QuranReadingPositionRecording: AnyObject {
    func recordReadingPosition(_ ayah: VerseReference)
    func flushReadingPosition() async
}

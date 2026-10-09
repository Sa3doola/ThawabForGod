/// The run of one ayah on one Mushaf line.
///
/// Here rather than in the app because `Tools/QuranBuilder` checks the layout with the same
/// segmentation the page renderer draws with.
public struct LineSegment<Word> {
    public let surah: Int
    public let ayah: Int
    /// The ayah's words on this line, in reading order, without its end marker.
    public var words: [Word]
    /// The ayah's end marker is on this line, after its last word.
    public var endsAyah: Bool

    @inlinable
    public init(surah: Int, ayah: Int, words: [Word], endsAyah: Bool) {
        self.surah = surah
        self.ayah = ayah
        self.words = words
        self.endsAyah = endsAyah
    }
}

extension LineSegment: Sendable where Word: Sendable {}
extension LineSegment: Equatable where Word: Equatable {}

public enum LineSegmentation {
    /// Splits a layout line's words (`first_word…last_word`, in id order, markers
    /// included) into per-ayah segments.
    ///
    /// An ayah's end marker can wrap to the start of the next line; that line then opens
    /// with a segment that has no words and `endsAyah == true`.
    ///
    /// Inlinable so it specializes in the app, which segments ~9,000 lines at launch.
    @inlinable
    public static func segments<Word>(
        _ words: some Sequence<Word>,
        reference: (Word) -> (surah: Int, ayah: Int, isMarker: Bool)
    ) -> [LineSegment<Word>] {
        var result: [LineSegment<Word>] = []
        var current: LineSegment<Word>?

        func flush(endsAyah: Bool) {
            guard var segment = current else { return }
            segment.endsAyah = endsAyah
            result.append(segment)
            current = nil
        }

        for word in words {
            let ref = reference(word)
            if let segment = current, (segment.surah, segment.ayah) != (ref.surah, ref.ayah) {
                flush(endsAyah: false)
            }
            if current == nil {
                current = LineSegment(surah: ref.surah, ayah: ref.ayah, words: [], endsAyah: false)
            }
            if ref.isMarker {
                flush(endsAyah: true)
            } else {
                current?.words.append(word)
            }
        }
        flush(endsAyah: false)
        return result
    }
}

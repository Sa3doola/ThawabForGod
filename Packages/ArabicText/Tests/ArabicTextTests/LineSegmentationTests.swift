import ArabicText
import Testing

struct LineSegmentationTests {
    struct W: Equatable { let surah: Int, ayah: Int, marker: Bool, text: String }

    private func segments(_ words: [W]) -> [LineSegment<W>] {
        LineSegmentation.segments(words) { ($0.surah, $0.ayah, $0.marker) }
    }

    @Test func splitsAtAyahMarkers() {
        let line = [
            W(surah: 1, ayah: 1, marker: false, text: "a"), W(surah: 1, ayah: 1, marker: true, text: "١"),
            W(surah: 1, ayah: 2, marker: false, text: "b"), W(surah: 1, ayah: 2, marker: false, text: "c"),
        ]
        let result = segments(line)
        #expect(result.map(\.ayah) == [1, 2])
        #expect(result.map(\.endsAyah) == [true, false])
        #expect(result[1].words.map(\.text) == ["b", "c"])
    }

    @Test func markerWrappedToTheNextLineIsAWordlessSegment() {
        let line = [W(surah: 2, ayah: 45, marker: true, text: "٤٥"), W(surah: 2, ayah: 46, marker: false, text: "x")]
        let result = segments(line)
        #expect(result.count == 2)
        #expect(result[0].words.isEmpty && result[0].endsAyah && result[0].ayah == 45)
        #expect(result[1].ayah == 46 && !result[1].endsAyah)
    }

    @Test func surahChangeWithoutMarkerStartsANewSegment() {
        let line = [W(surah: 1, ayah: 7, marker: false, text: "a"), W(surah: 2, ayah: 1, marker: false, text: "b")]
        #expect(segments(line).map { "\($0.surah):\($0.ayah)" } == ["1:7", "2:1"])
    }

    @Test func emptyLineHasNoSegments() {
        #expect(segments([]).isEmpty)
    }
}

import CoreGraphics
import Testing
@testable import ThawabForGod

/// Ported from Mushaf's PageUnitTests (the fold-kind rule), plus the DEBUG fold override that
/// replaced Mushaf's `-debugFold` UserDefaults read. `resolve(in:)` needs a GeometryProxy and is
/// deliberately not tested here.
struct FoldGeometryTests {
    @Test func foldKindFollowsTheGutter() {
        #expect(FoldGeometry(leadingWidth: 488, gutterWidth: 24, trailingWidth: 488).kind == .book)
        #expect(FoldGeometry(leadingWidth: 500, gutterWidth: 0, trailingWidth: 500).kind == .flat)
    }

    @Test func verticalOverrideSplitsTheWidthAroundTheHinge() throws {
        let override = try #require(FoldGeometry.DebugOverride(axis: .vertical, argument: "0.55,24"))
        let division = override.division(in: CGSize(width: 1000, height: 800))
        #expect(division == .vertical(FoldGeometry(leadingWidth: 538, gutterWidth: 24, trailingWidth: 438)))
        #expect(division.vertical?.kind == .book)
    }

    @Test func flatOverrideHasNoGutter() throws {
        let override = try #require(FoldGeometry.DebugOverride(axis: .vertical, argument: "0.5,0"))
        let fold = try #require(override.division(in: CGSize(width: 1000, height: 800)).vertical)
        #expect(fold == FoldGeometry(leadingWidth: 500, gutterWidth: 0, trailingWidth: 500))
        #expect(fold.kind == .flat)
    }

    @Test func horizontalOverrideIsTabletop() throws {
        let override = try #require(FoldGeometry.DebugOverride(axis: .horizontal, argument: "0.5,24"))
        let division = override.division(in: CGSize(width: 1000, height: 800))
        #expect(division == .horizontal(topHeight: 388, gutterHeight: 24, bottomHeight: 388))
        #expect(division.vertical == nil)
    }

    @Test(arguments: ["", "0.5", "a,b", "1.5,24", "0.5,-4", "0.5,24,3", "0.5,inf"])
    func malformedArgumentsAreNoOverride(_ argument: String) {
        #expect(FoldGeometry.DebugOverride(axis: .vertical, argument: argument) == nil)
        #expect(FoldGeometry.DebugOverride(axis: .horizontal, argument: argument) == nil)
    }

    @Test func divisionVerticalAccessor() {
        let fold = FoldGeometry(leadingWidth: 400, gutterWidth: 24, trailingWidth: 376)
        #expect(FoldGeometry.Division.vertical(fold).vertical == fold)
    }
}

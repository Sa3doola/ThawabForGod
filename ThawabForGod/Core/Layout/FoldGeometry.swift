//
//  FoldGeometry.swift
//  ThawabForGod
//

import SwiftUI

/// Where a display with a fold divides, measured — for a layout that has to put something on
/// each side of it.
///
/// Mushaf's `MushafFold`, moved to Core because a fold is a property of the device rather than of
/// the Quran (QURAN_MIGRATION_PLAN.md, T12). **One helper, one caller**: the Mushaf pager is the
/// only screen that *measures* the fold, because a printed spread has to put its gutter exactly
/// over the hinge. The adhkar reader does not measure anything — it hands the split to the system's
/// `ArrangementView`, which is the better tool whenever the system's own split is good enough — and
/// that is deliberately not routed through here.
///
/// Widths are measured from the leading edge, which in a right-to-left layout is the right edge:
/// in the Mushaf pager `leadingWidth` holds the odd (right-hand) page.
nonisolated struct FoldGeometry: Equatable, Sendable {
    let leadingWidth: CGFloat
    let gutterWidth: CGFloat
    let trailingWidth: CGFloat

    /// A fold with a gutter is bent (book pose, the hinge active); without one the display lies
    /// flat.
    var kind: FoldKind { gutterWidth > 0 ? .book : .flat }

    /// A division of the display: vertical (book pose or flat, one thing each side) or horizontal
    /// (tabletop or tent: one thing above, another below).
    enum Division: Equatable, Sendable {
        case vertical(FoldGeometry)
        /// Heights from the top edge; `gutterHeight` is the hinge, 0 while inactive.
        case horizontal(topHeight: CGFloat, gutterHeight: CGFloat, bottomHeight: CGFloat)

        var vertical: FoldGeometry? {
            if case .vertical(let fold) = self { fold } else { nil }
        }
    }

    /// The vertical fold in this geometry, if there is one.
    @MainActor
    static func resolve(in geometry: GeometryProxy, override: DebugOverride? = nil) -> FoldGeometry? {
        resolveDivision(in: geometry, override: override)?.vertical
    }

    /// The display's fold in this geometry, if there is one.
    ///
    /// Follows Apple's guidance for foldable iPhones: inactive regions are queried too, so a layout
    /// does not jump while the device is being folded; a zero-sized inactive frame means an even
    /// vertical split; and the gutter widens only while the fold is active. A horizontal fold is
    /// reported only while active (tabletop or tent) — lying flat, content simply runs across it.
    ///
    /// - Parameter override: a simulated fold for the simulator, which cannot be posed (DEBUG
    ///   builds only; see `DebugOverride`). Wins over the real geometry when given.
    @MainActor
    static func resolveDivision(in geometry: GeometryProxy, override: DebugOverride? = nil) -> Division? {
        #if DEBUG
        if let override { return override.division(in: geometry.size) }
        #endif
        #if os(iOS)
        if #available(iOS 27.1, *) {
            // The default `.mirrors` behaviour: frames follow the layout direction, so in a
            // right-to-left layout minX is measured from the right edge, matching the leading side.
            for division in geometry.reservedRegions(kind: .division, options: .includeInactive) {
                let frame = division.frame
                let size = geometry.size
                if frame.isEmpty {
                    return .vertical(FoldGeometry(leadingWidth: size.width / 2, gutterWidth: 0, trailingWidth: size.width / 2))
                }
                if frame.height > frame.width {
                    let gutter = division.isActive ? frame.width : 0
                    let center = frame.midX
                    return .vertical(FoldGeometry(
                        leadingWidth: max(0, center - gutter / 2),
                        gutterWidth: gutter,
                        trailingWidth: max(0, size.width - center - gutter / 2)
                    ))
                }
                guard division.isActive else { continue }
                return .horizontal(
                    topHeight: max(0, frame.minY),
                    gutterHeight: frame.height,
                    bottomHeight: max(0, size.height - frame.maxY)
                )
            }
        }
        #endif
        return nil
    }
}

/// The kind of vertical fold: a book (the hinge is bent, or active) or a display lying flat.
nonisolated enum FoldKind: Hashable, Sendable {
    case book, flat
}

extension FoldGeometry {
    /// A fold to pretend the display has, so the fold paths can be exercised on a simulator or a
    /// Mac, neither of which can be posed. Parsed from a launch argument by the Quran's DEBUG launch
    /// options and handed in, rather than read from `UserDefaults` here: Core does not reach into
    /// process-wide state to decide a layout.
    ///
    /// Compiled into every build so a caller can hold one without `#if`, but only a DEBUG build's
    /// `resolveDivision` ever applies it.
    nonisolated struct DebugOverride: Equatable, Sendable {
        enum Axis: Equatable, Sendable { case vertical, horizontal }

        let axis: Axis
        /// Where the hinge's centre is, as a share of the width (vertical) or height (horizontal).
        let position: CGFloat
        /// The hinge's width (vertical) or height (horizontal) in points; 0 is a display open flat.
        let gutter: CGFloat

        /// `"0.55,24"`: a hinge at 55% with a 24 pt gutter. `nil` for anything else, so a mistyped
        /// argument is no override rather than a nonsense one.
        init?(axis: Axis, argument: String) {
            let values = argument.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard values.count == 2, (0...1).contains(values[0]), values[1].isFinite, values[1] >= 0 else { return nil }
            self.axis = axis
            position = values[0]
            gutter = values[1]
        }

        /// The division this override describes on a display of `size`.
        func division(in size: CGSize) -> Division {
            switch axis {
            case .vertical:
                let center = size.width * position
                return .vertical(FoldGeometry(
                    leadingWidth: max(0, center - gutter / 2),
                    gutterWidth: gutter,
                    trailingWidth: max(0, size.width - center - gutter / 2)
                ))
            case .horizontal:
                let center = size.height * position
                return .horizontal(
                    topHeight: max(0, center - gutter / 2),
                    gutterHeight: gutter,
                    bottomHeight: max(0, size.height - center - gutter / 2)
                )
            }
        }
    }
}

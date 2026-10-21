//
//  MonthPager.swift
//  ThawabForGod
//

import SwiftUI

/// The months side by side, one per page.
///
/// A horizontal `ScrollView` with paging rather than `TabView(.page)`, which is iOS-only — the
/// same choice the adhkar reader makes. The scroll view follows the layout direction on its own,
/// so in Arabic the next month is to the left without anything here saying so.
struct MonthPager: View {
    let viewModel: HijriCalendarViewModel

    @State private var position: HijriMonthKey?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Row heights that grow with the reader's text size, so a cell never clips its numbers. The
    /// second is for a cell that also carries the Gregorian number under the Hijri one.
    @ScaledMetric(relativeTo: .body) private var plainRowHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var gregorianRowHeight: CGFloat = 72

    private let rowSpacing: CGFloat = 4

    /// The Gregorian number is not drawn at accessibility sizes, so the short row is enough there.
    private var rowHeight: CGFloat {
        viewModel.showGregorian && !dynamicTypeSize.isAccessibilitySize ? gregorianRowHeight : plainRowHeight
    }

    init(viewModel: HijriCalendarViewModel) {
        self.viewModel = viewModel
        // Seeded here so the first frame is already on the right month instead of the oldest.
        _position = State(initialValue: viewModel.visibleMonth)
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(viewModel.months, id: \.self) { key in
                    MonthGridView(key: key, viewModel: viewModel, rowHeight: rowHeight)
                        .containerRelativeFrame(.horizontal)
                        .id(key)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $position)
        .onChange(of: position) { _, new in
            if let new, new != viewModel.visibleMonth { viewModel.show(new) }
        }
        .onChange(of: viewModel.visibleMonth) { _, new in
            if position != new { withAnimation { position = new } }
        }
        // Six rows of cells, which is the most a month needs, so the pager does not change
        // height as the reader pages between a five-row month and a six-row one.
        .frame(height: 6 * rowHeight + 5 * rowSpacing)
    }
}

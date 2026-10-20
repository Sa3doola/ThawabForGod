//
//  NavigationPathBinding.swift
//  ThawabForGod
//

import SwiftUI

extension Binding {
    /// A typed `[Route]` path presented as the `NavigationPath` every other section binds, so the
    /// stacks in the split view's detail column all share one path type (a column handed
    /// `[QuranRoute]` and then `NavigationPath` once trapped in `NavigationColumnState.boundPathChange`).
    /// `MainSplitView` also rebuilds the column per section, which is what actually fixed the crash;
    /// this keeps the types uniform and the coordinators' typed paths (`path.last == .reader`).
    ///
    /// Reading converts the array. Writing only trims it, because these stacks are pushed through
    /// the coordinators and never with `NavigationLink(value:)`: a push SwiftUI made itself would be
    /// dropped here.
    ///
    /// `isActive` says whether this stack's section is on screen. A stack being torn down because
    /// the reader chose another section reports an empty path on its way out; without the check
    /// that write would pop the screen the reader left open.
    func navigationPath<Route: Hashable>(isActive: @escaping () -> Bool = { true }) -> Binding<NavigationPath> where Value == [Route] {
        Binding<NavigationPath>(
            get: { NavigationPath(wrappedValue) },
            set: { newPath in
                guard isActive() else { return }
                let count = Swift.min(newPath.count, wrappedValue.count)
                if count < wrappedValue.count {
                    wrappedValue = Array(wrappedValue.prefix(count))
                }
            }
        )
    }
}

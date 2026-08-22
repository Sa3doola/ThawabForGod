//
//  ReaderPaper.swift
//  ThawabForGod
//

import Foundation

/// The colour of the page under a long passage of text.
///
/// Deliberately not `AppearanceOverride`, which is the whole app's light/dark switch. This one is
/// narrower and it is *fixed*: a reader who chose parchment for an evening's reading did not ask
/// for the page to turn white when the phone's own appearance schedule flips at sunrise. So the
/// two named papers carry the same value in light and dark both, and only `.system` follows the
/// app.
///
/// It lives in `Core/Theming` rather than in the Quran feature because a paper is a palette, and
/// `AppColor` is the only file in the app entitled to name an asset colour. The reader is its
/// first caller, not its owner.
nonisolated enum ReaderPaper: String, CaseIterable, Identifiable, Sendable {

    /// Follows the app: `Theme`'s own background and text, light or dark as the system says.
    case system

    /// Warm off-white with dark brown ink, in either appearance.
    case parchment

    /// Near-black with warm off-white ink, in either appearance.
    case night

    static let fallback: ReaderPaper = .system

    var id: String { rawValue }

    /// Name of the colour-set prefix in the asset catalog, for the two papers that have one.
    ///
    /// `nil` for `.system`, which has no colours of its own — it borrows the theme's. That `nil`
    /// is what `Theme.reading(_:)` switches on, so the "follows the app" case is expressed once
    /// rather than in every colour lookup.
    var assetPrefix: String? {
        switch self {
        case .system: nil
        case .parchment: "PaperParchment"
        case .night: "PaperNight"
        }
    }

    var labelKey: L10nKey {
        switch self {
        case .system: .readerPaperSystem
        case .parchment: .readerPaperParchment
        case .night: .readerPaperNight
        }
    }
}

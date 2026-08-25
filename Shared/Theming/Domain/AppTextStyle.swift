//
//  AppTextStyle.swift
//  ThawabForGod
//

import CoreGraphics // CGFloat; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Foundation

/// The app's type scale. Each case maps to a system text style in `AppFont`, so every
/// size scales with Dynamic Type.
///
/// Two metrics travel with each step besides its size, and both of them depend on the script the
/// step is being set in — which is why they are functions rather than stored values. See
/// `tracking(isArabic:)` and `additionalLineSpacing(isArabic:)`.
nonisolated enum AppTextStyle: String, CaseIterable, Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case footnote
    case caption

    /// The step's size at the default content size category, as the design states it.
    ///
    /// The app sets type through `Font.TextStyle`, so this number is never used to *draw*
    /// anything — the system's own metrics do that, and they are the reason Dynamic Type works
    /// at all. It exists because leading is specified as a fraction of the size, and a fraction
    /// needs something to be a fraction of. `AppFontModifier` scales it the same way the system
    /// scales the face.
    var nominalSize: CGFloat {
        switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        }
    }

    /// How much to tighten this step, in points.
    ///
    /// Only the two display steps are tightened, and only in Latin. **Arabic never takes a
    /// negative tracking value** — the design says so and the reason is mechanical rather than
    /// aesthetic: Arabic is a joined script, so negative tracking pulls the connecting strokes
    /// into the letterforms beside them and a word stops reading as a word. A rule that held for
    /// the interface language but not for a chapter's name inside an English list would be no
    /// rule at all, which is why this is asked per *text* and not once per app.
    ///
    /// The values are absolute points rather than a fraction of the size, as the design states
    /// them. That means they do not grow with Dynamic Type, which is correct: tracking is there
    /// to stop a large title looking loose, and at an accessibility size the title is no longer
    /// the thing the eye is measuring.
    func tracking(isArabic: Bool) -> CGFloat {
        guard !isArabic else { return 0 }

        return switch self {
        case .largeTitle: -0.4
        case .title: -0.3
        default: 0
        }
    }

    /// Extra leading for Arabic, as a fraction of the step's own size.
    ///
    /// Arabic sits on a taller body than Latin — it has ascenders, descenders and a full deck of
    /// marks above and below the line — so a leading chosen for Latin puts the dots of one line
    /// into the marks of the next. The design's number is 0.35 of the size, at every step.
    ///
    /// It is applied as `lineSpacing`, which is the gap *between* lines and does nothing at all
    /// to a label that fits on one. So this costs nothing everywhere it is not needed, and the
    /// places it is needed — a wrapped dhikr, a narration, a name's meaning — are exactly the
    /// places it shows.
    func additionalLineSpacing(isArabic: Bool, size: CGFloat) -> CGFloat {
        isArabic ? size * 0.35 : 0
    }
}

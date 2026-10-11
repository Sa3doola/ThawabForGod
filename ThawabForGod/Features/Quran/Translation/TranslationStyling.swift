//
//  TranslationStyling.swift
//  ThawabForGod
//

import SwiftUI

/// The half of Mushaf's `TranslationMarkup.swift` that needs SwiftUI's `Font` and `Color`.
nonisolated extension TranslationDocument {
    /// Styled text: italics as emphasis, each footnote a raised, smaller number that links to
    /// `footnote://ID` in `markerColor`. `fontSize` is in points, already scaled for Dynamic Type;
    /// `number` formats a footnote's number in the reader's digits.
    func attributedString(fontSize: CGFloat, markerColor: Color, number: (Int) -> String) -> AttributedString {
        var result = AttributedString()
        for piece in pieces {
            switch piece {
            case .text(let text, let italic):
                var run = AttributedString(text)
                if italic { run.inlinePresentationIntent = .emphasized }
                result += run
            case .footnote(let footnoteNumber, let id, _):
                var marker = AttributedString(number(footnoteNumber))
                marker.font = QuranFaces.chromeFont(size: fontSize * 0.62, weight: .semibold)
                marker.baselineOffset = fontSize * 0.38
                marker.foregroundColor = markerColor
                marker.link = URL(string: "\(Self.footnoteScheme)://\(id)")
                result += marker
            }
        }
        return result
    }
}

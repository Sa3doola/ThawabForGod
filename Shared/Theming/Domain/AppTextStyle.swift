//
//  AppTextStyle.swift
//  ThawabForGod
//

import Foundation

/// The app's type scale. Each case maps to a system text style in `AppFont`, so every
/// size scales with Dynamic Type.
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
}

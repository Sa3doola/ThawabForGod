//
//  AppFont.swift
//  ThawabForGod
//

import SwiftUI

/// Supplies a `Font` for each step of the type scale.
///
/// A protocol rather than a bare enum so a bespoke Arabic face can be swapped in later
/// without touching a single call site.
nonisolated protocol AppFontProviding: Sendable {
    func font(_ style: AppTextStyle, weight: Font.Weight) -> Font

    /// The face a long passage of scripture is set in, at a size the reader chose.
    ///
    /// The one place a size comes from outside the type scale — see `ReaderTypography` for why
    /// the reader gets points rather than a step. It is on the protocol rather than free-standing
    /// so that the bespoke Uthmani face this protocol exists to allow can override *this* without
    /// touching the ten steps above it: a Quranic face is a different design at a different
    /// optical size, and the reader is the only screen that would want it.
    func readingFont(_ face: ReaderFont, size: Double) -> Font
}

nonisolated extension AppFontProviding {
    func font(_ style: AppTextStyle) -> Font {
        font(style, weight: .regular)
    }

    /// Takes a size that has *already* been scaled for Dynamic Type — see `ReadingFontModifier`,
    /// which is where that happens and why it has to. A conforming provider should treat this
    /// argument as final and not scale it a second time.
    func readingFont(_ face: ReaderFont, size: Double) -> Font {
        face.font(size: size)
    }
}

/// Default provider: the system face, which resolves to SF Arabic for Arabic text.
/// Built on `Font.TextStyle`, so every size follows Dynamic Type.
nonisolated struct SystemAppFont: AppFontProviding {
    func font(_ style: AppTextStyle, weight: Font.Weight) -> Font {
        .system(style.textStyle, design: .default).weight(weight)
    }
}

/// IBM Plex Sans Arabic, at every step of the scale — the app's own face everywhere outside the
/// scripture.
///
/// Plex carries a full Latin set alongside the Arabic, so one provider serves both interface
/// languages and an English screen with an Arabic chapter name in it is set in one family rather
/// than two that were never drawn to sit together.
///
/// **Built on `Font.custom(_:size:relativeTo:)`, never a bare size**, so every step still follows
/// Dynamic Type exactly as the system face did. The sizes are the platform's own defaults for each
/// text style: macOS sets its whole scale four points smaller than iOS, and a Mac window full of
/// iPhone-sized body text would read as a zoomed screenshot.
///
/// The faces are registered by `FontRegistrar` in the app process only. Anything else that reads
/// this — a preview, the widget — would get the system face from CoreText's fallback, which is why
/// only the app's root injects it and `SystemAppFont` stays the environment's default.
nonisolated struct PlexAppFont: AppFontProviding {

    /// The five weights the app bundles. ExtraLight and Thin exist and are deliberately left out:
    /// hairline Arabic on a phone is a legibility problem before it is a style.
    enum Weight: String, CaseIterable, Sendable {
        case light = "IBMPlexSansArabic-Light"
        case regular = "IBMPlexSansArabic-Regular"
        case medium = "IBMPlexSansArabic-Medium"
        case semiBold = "IBMPlexSansArabic-SemiBold"
        case bold = "IBMPlexSansArabic-Bold"

        var postScriptName: String { rawValue }

        /// The nearest bundled weight. Everything lighter than light rounds up to it and
        /// everything heavier than bold rounds down, rather than asking CoreText to synthesise a
        /// weight the family was never drawn in.
        init(_ weight: Font.Weight) {
            switch weight {
            case .ultraLight, .thin, .light: self = .light
            case .medium: self = .medium
            case .semibold: self = .semiBold
            case .bold, .heavy, .black: self = .bold
            default: self = .regular
            }
        }
    }

    func font(_ style: AppTextStyle, weight: Font.Weight) -> Font {
        .custom(
            Self.weight(for: style, requested: weight).postScriptName,
            size: Self.defaultSize(of: style),
            relativeTo: style.textStyle
        )
    }

    /// The system's headline *is* its body at semibold — that weight is what makes it a headline.
    /// A custom face has no text style to borrow the weight from, so an unqualified `.headline`
    /// asks for it here, or every heading in the app would quietly turn into body copy.
    private static func weight(for style: AppTextStyle, requested: Font.Weight) -> Weight {
        if style == .headline, requested == .regular { return .semiBold }
        return Weight(requested)
    }

    /// Apple's default size for each text style on this platform — the size `relativeTo:` scales
    /// from.
    static func defaultSize(of style: AppTextStyle) -> CGFloat {
        #if os(macOS)
        switch style {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .headline: 13
        case .body: 13
        case .callout: 12
        case .subheadline: 11
        case .footnote: 10
        case .caption: 10
        }
        #else
        style.nominalSize
        #endif
    }
}

// Extensions pick up the module's `MainActor` default isolation, so this one opts out —
// the type it extends is `nonisolated` and the mapping is pure.
nonisolated extension AppTextStyle {
    var textStyle: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption
        }
    }
}

extension View {
    /// Applies a step of the app's type scale. Use this instead of `.font(...)`.
    func appFont(_ style: AppTextStyle, weight: Font.Weight = .regular) -> some View {
        modifier(AppFontModifier(style: style, weight: weight))
    }

    /// Applies the reading face at the reader's chosen size, with the leading that face needs.
    /// Only the scripture uses this; everything around it stays on `appFont(_:weight:)`.
    ///
    /// `face` pins a face regardless of the reader's choice — `nil` takes the one in
    /// `\.readingStyle`. `extraLineSpacing` is added to the face's own floor — see
    /// `ReaderFont.lineSpacing(for:)`.
    func readingFont(
        size: Double,
        face: ReaderFont? = nil,
        extraLineSpacing: Double = 0
    ) -> some View {
        modifier(ReadingFontModifier(size: size, face: face, extraLineSpacing: extraLineSpacing))
    }
}

/// Applies a step of the scale — the face, and the two metrics that go with it.
///
/// **The script decides both of them, and the script is read from `\.locale`.** That is the one
/// signal that is right per *text* rather than per app: the whole hierarchy carries the interface
/// language, and the handful of leaves that draw Arabic inside an English screen — a chapter's
/// name, a verse, a dhikr — already pin `\.locale` to Arabic so that VoiceOver reads them in the
/// right voice. Asking the same question for type means an Arabic name in an English list is set
/// as Arabic, which a per-app answer could never manage.
private struct AppFontModifier: ViewModifier {
    @Environment(\.appFont) private var provider
    @Environment(\.locale) private var locale

    /// The step's nominal size, scaled the way the system scales the face it belongs to — so the
    /// leading derived from it grows with Dynamic Type instead of staying at its default-size
    /// value while the text around it doubles.
    @ScaledMetric private var scaledSize: CGFloat

    let style: AppTextStyle
    let weight: Font.Weight

    init(style: AppTextStyle, weight: Font.Weight) {
        self.style = style
        self.weight = weight
        _scaledSize = ScaledMetric(wrappedValue: style.nominalSize, relativeTo: style.textStyle)
    }

    func body(content: Content) -> some View {
        content
            .font(provider.font(style, weight: weight))
            .tracking(style.tracking(isArabic: isArabic))
            .lineSpacing(style.additionalLineSpacing(isArabic: isArabic, size: scaledSize))
    }

    private var isArabic: Bool {
        locale.language.languageCode?.identifier == "ar"
    }
}

/// Applies the reader's chosen size, scaled for Dynamic Type.
///
/// The scaling is here rather than inside the `Font` because SwiftUI has no system-font
/// equivalent of `Font.custom(_:size:relativeTo:)` — `Font.system(size:)` is a fixed number of
/// points and ignores the content size category entirely. `@ScaledMetric` is what closes that
/// gap: seeded with `1` it scales *itself* by the same factor `UIFontMetrics` would apply at
/// `.title3`, which makes it a multiplier rather than a size. Without this, a reader who has
/// enlarged text system-wide would find the one screen in the app made of nothing but text was
/// also the only one that ignored the setting.
private struct ReadingFontModifier: ViewModifier {
    @Environment(\.appFont) private var provider
    /// The reader's choice inside `ReaderView`; `ReaderFont.fallback` anywhere nothing resolved
    /// one.
    @Environment(\.readingStyle) private var style
    @ScaledMetric(relativeTo: .title3) private var typeScale: CGFloat = 1
    let size: Double
    let face: ReaderFont?
    let extraLineSpacing: Double

    func body(content: Content) -> some View {
        let scaledSize = size * Double(typeScale)
        let face = face ?? style.font

        content
            .font(provider.readingFont(face, size: scaledSize))
            // The face's own floor, scaled with the text, plus whatever the caller adds on top.
            // Set here rather than by the caller because the innermost `lineSpacing` wins: a
            // caller's value applied outside this modifier would be silently ignored.
            .lineSpacing(face.lineSpacing(for: scaledSize) + extraLineSpacing)
    }
}

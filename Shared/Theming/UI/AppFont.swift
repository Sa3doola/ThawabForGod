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
    func readingFont(font: QuranAppFont, size: Double) -> Font
}

nonisolated extension AppFontProviding {
    func font(_ style: AppTextStyle) -> Font {
        font(style, weight: .regular)
    }

    /// Takes a size that has *already* been scaled for Dynamic Type — see `ReadingFontModifier`,
    /// which is where that happens and why it has to. A conforming provider should treat this
    /// argument as final and not scale it a second time.
    func readingFont(font: QuranAppFont, size: Double) -> Font {
        .custom(font.rawValue, size: size)
    }
}

/// Default provider: the system face, which resolves to SF Arabic for Arabic text.
/// Built on `Font.TextStyle`, so every size follows Dynamic Type.
nonisolated struct SystemAppFont: AppFontProviding {
    func font(_ style: AppTextStyle, weight: Font.Weight) -> Font {
        .system(style.textStyle, design: .default).weight(weight)
    }
}

nonisolated enum QuranAppFont: String {
    case alMajeedQuranicFont = "AlMajeedQuranicFont"
    case alMushafQuran = "AlMushafQuran"
    case alQuranAli = "AlQuranAli-L3A83"
    case amiriQuran = "AmiriQuran-Regular"
    case hafsUthmanicScriptRegular = "HafsUthmanicScriptRegular"
    case quranKarim114 = "QuranKarim114"
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

    /// Applies the reading face at the reader's chosen size. Only the scripture uses this;
    /// everything around it stays on `appFont(_:weight:)`.
    func readingFont(size: Double) -> some View {
        modifier(ReadingFontModifier(size: size))
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
    @ScaledMetric(relativeTo: .title3) private var typeScale: CGFloat = 1
    let size: Double

    func body(content: Content) -> some View {
        content.font(provider.readingFont(font: .alQuranAli, size: size * Double(typeScale)))
    }
}

//
//  AppElevation.swift
//  ThawabForGod
//

import SwiftUI

/// The three elevation steps, and the only place a shadow is written down.
///
/// The values are tuned to the light ground — a warm near-black at low opacity, so a card reads
/// as lifted off cream rather than as outlined in grey. **On a dark ground they are drawn as
/// nothing at all.** A drop shadow needs a surface lighter than the thing behind it to cast
/// onto; on `#0E0D0C` it only smears the edge it was meant to sharpen, and the separator hairline
/// — which every surface already carries — is what does the lifting there instead.
///
/// That branch is the reason this is a modifier reading `\.colorScheme` rather than a constant
/// beside `AppSpacing`. It is the one place in the design system that has to know the appearance,
/// and it is here so that no view does.
nonisolated enum AppElevation: Sendable {
    /// A card sitting on the background.
    case card
    /// A sheet or a panel over the screen.
    case sheet
    /// The top of the stack — a popover, a dialog.
    case popover

    fileprivate var radius: CGFloat {
        switch self {
        case .card: 2
        case .sheet: 14
        case .popover: 32
        }
    }

    fileprivate var y: CGFloat {
        switch self {
        case .card: 1
        case .sheet: 4
        case .popover: 12
        }
    }

    fileprivate var opacity: Double {
        switch self {
        case .card: 0.08
        case .sheet: 0.10
        case .popover: 0.16
        }
    }
}

extension View {
    /// Lifts a surface by one of the three steps. Use this instead of `.shadow(...)`.
    func appElevation(_ step: AppElevation) -> some View {
        modifier(AppElevationModifier(step: step))
    }
}

private struct AppElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let step: AppElevation

    /// The warm near-black the whole scale is cast in — `rgba(30, 20, 10, …)`. Not a token,
    /// because it is never seen: it is only ever the colour of a blur at eight per cent.
    private static let ink = Color(.sRGB, red: 30 / 255, green: 20 / 255, blue: 10 / 255)

    func body(content: Content) -> some View {
        content.shadow(
            color: Self.ink.opacity(colorScheme == .dark ? 0 : step.opacity),
            radius: step.radius / 2,
            y: step.y
        )
    }
}

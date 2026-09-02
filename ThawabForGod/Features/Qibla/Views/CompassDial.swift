//
//  CompassDial.swift
//  ThawabForGod
//

import SwiftUI

/// The live compass: a dial that turns with the device, and a needle that stays on the Kaaba.
///
/// Both rotations come from the same pair of angles, which is what keeps them honest — the
/// dial is turned by `-deviceHeading` so its north marker sits over true north, and the needle
/// by `needleRotation`, which is the bearing measured in the same turned frame.
///
/// **Arriving is a moment, and the instrument marks it three ways.** A ring closes around the
/// dial, the needle takes the fixed `success` colour, and the phone gives one bump. Three
/// because they reach different people: the ring is the thing seen from a foot away with the
/// phone held out flat, the colour survives being glanced at, and the bump is the only one of
/// them that works for somebody who is not looking at the screen — which, on this screen, is
/// most of the point. The state itself is `QiblaViewModel.isAlignedWithQibla`, with the
/// hysteresis that keeps all three from chattering.
struct CompassDial: View {
    let viewModel: QiblaViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private let diameter: CGFloat = 260

    var body: some View {
        ZStack {
            dial
            QiblaAlignmentRing(isAligned: viewModel.isAlignedWithQibla)
            QiblaNeedle()
                .fill(viewModel.isAlignedWithQibla ? theme.success : theme.accent)
                .frame(width: 34, height: diameter * 0.78)
                .rotationEffect(.degrees(viewModel.needleRotation))
        }
        .frame(width: diameter, height: diameter)
        // A compass is geometry, not text: mirroring it for Arabic would put north on the
        // wrong side of the dial and point the needle away from the Kaaba. The labels around
        // it still mirror — this pins the instrument alone.
        .environment(\.layoutDirection, .leftToRight)
        .animation(.easeOut(duration: 0.2), value: viewModel.needleRotation)
        // Slower than the needle, and separate from it: the needle is tracking a hand, while
        // this is a state changing, and giving both the same curve would make the ring look
        // like part of the tracking rather than an answer to it.
        .animation(.easeOut(duration: 0.28), value: viewModel.isAlignedWithQibla)
        // One bump on arrival, and nothing on the way out — a haptic when the user turns away
        // would be the phone objecting rather than confirming. A single `impact` rather than
        // the `success` chord `TasbihCounterView` uses for a finished lap: this is a threshold
        // being crossed and it can be crossed again a second later, so it wants the shortest
        // thing the Taptic Engine can say.
        .sensoryFeedback(trigger: viewModel.isAlignedWithQibla) { wasAligned, isAligned in
            isAligned && !wasAligned ? .impact(weight: .medium) : nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.string(.qiblaNeedleLabel))
        .accessibilityValue(accessibilityValue)
    }

    /// The bearing, and — when it is true — the one fact the ring and the haptic are carrying.
    ///
    /// A format string rather than two views or a joined pair, because the separator between a
    /// number and a clause is a punctuation decision that differs by language; Arabic's comma is
    /// not `,`. See `qibla_aligned_value`.
    private var accessibilityValue: String {
        let bearing = l10n.degreesString(viewModel.qiblaDirection)

        guard viewModel.isAlignedWithQibla else { return bearing }
        return l10n.string(.qiblaAlignedValue, bearing)
    }

    private var dial: some View {
        ZStack {
            Circle()
                .fill(theme.surface)
            Circle()
                .strokeBorder(theme.separator, lineWidth: 1)

            ForEach(0..<72, id: \.self) { index in
                // Every fifth mark — 25° apart is too coarse, so the ring is 72 marks and
                // every sixth is a major one, giving a labelled quarter at each cardinal.
                Capsule()
                    .fill(index.isMultiple(of: 6) ? theme.textSecondary : theme.separator)
                    .frame(width: 1.5, height: index.isMultiple(of: 6) ? 12 : 6)
                    .offset(y: -(diameter / 2) + 12)
                    .rotationEffect(.degrees(Double(index) * 5))
            }

            Text(l10n.string(.qiblaNorthMarker))
                .appFont(.footnote, weight: .bold)
                .foregroundStyle(theme.textSecondary)
                .offset(y: -(diameter / 2) + 30)
        }
        .rotationEffect(.degrees(-viewModel.deviceHeading))
    }
}

/// The border that closes around the dial when the phone is facing the Kaaba.
///
/// **It breathes rather than blinks.** A ring that appeared and then held still is hard to tell
/// from the dial's own edge at a glance, and one that flashed would read as an alarm — so it
/// holds a slow one-second swell, which says confirmation and survives being seen out of the
/// corner of an eye. The pulse is one `withAnimation(.repeatForever)` over a single
/// `Bool`: the value changes once, and the autoreversing repeat is what carries it back and
/// forth for as long as the ring is on screen.
///
/// **The ring exists only while aligned**, rather than living at zero opacity, so its pulse
/// state is created and destroyed with it — an animation left armed behind an invisible view is
/// the sort of thing that runs for the life of the screen and shows up in a trace.
///
/// Reduce Motion gets the ring without the swell. The information is the ring; the movement is
/// only how it asks to be noticed, so removing it costs nothing that has to be replaced.
private struct QiblaAlignmentRing: View {
    let isAligned: Bool

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPulsing = false

    var body: some View {
        if isAligned {
            Circle()
                .strokeBorder(theme.success, lineWidth: 3)
                // Outside the dial's own border rather than on top of it, so the two read as an
                // instrument and a ring around it instead of one thickened edge.
                .padding(-4)
                .opacity(isPulsing ? 0.4 : 1)
                .scaleEffect(isPulsing ? 1.02 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
                .onDisappear { isPulsing = false }
                .transition(.opacity)
                // The ring says what `accessibilityValue` on the dial already says in words.
                .accessibilityHidden(true)
        }
    }
}

/// A slim arrow pointing at twelve o'clock, so a rotation of zero means "straight ahead".
private struct QiblaNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let headHeight = rect.height * 0.28

        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + headHeight))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.14, y: rect.minY + headHeight))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.14, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - rect.width * 0.14, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - rect.width * 0.14, y: rect.minY + headHeight))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + headHeight))
        path.closeSubpath()

        return path
    }
}
// MARK: - Previews

/// The alignment states, which no test can reach and no simulator can produce: the canvas is
/// the only place the ring, the tint and the transition between them can actually be looked at.
/// A simulator has no magnetometer, so this screen degrades to the static readout there.
private func previewViewModel(facingTheQibla: Bool) -> QiblaViewModel {
    let viewModel = QiblaViewModel(
        getQiblaInfo: GreatCircleQiblaInfoUseCase(engine: PrayerTimeEngine()),
        locationService: CoreLocationService(settingsStore: InMemorySettingsStore()),
        headingProvider: CoreLocationHeadingProvider(),
        coordinates: Coordinates(latitude: 51.5074, longitude: -0.1278)
    )

    viewModel.apply(
        DeviceHeading(
            trueHeading: facingTheQibla ? viewModel.qiblaDirection : viewModel.qiblaDirection + 70,
            accuracy: 5
        )
    )

    return viewModel
}

@MainActor
private func previewDial(facingTheQibla: Bool) -> some View {
    let settingsStore = InMemorySettingsStore()

    return CompassDial(viewModel: previewViewModel(facingTheQibla: facingTheQibla))
        .padding(AppSpacing.xxl)
        .themed(ThemeManager(settingsStore: settingsStore))
        .localized(
            LocalizationManager(
                settingsStore: settingsStore,
                numberFormatting: LocaleNumberFormattingService(),
                timeFormatting: LocaleTimeFormattingService()
            )
        )
}

#Preview("Facing the Qibla") {
    previewDial(facingTheQibla: true)
}

#Preview("Turned away") {
    previewDial(facingTheQibla: false)
}

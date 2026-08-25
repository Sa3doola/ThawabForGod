//
//  QiblaReadout.swift
//  ThawabForGod
//

import SwiftUI

/// The numbers behind the needle: bearing, distance, and the position they were measured from.
///
/// This is the whole screen on a Mac, and a cross-check on a phone — a user who suspects the
/// compass can read the bearing off a paper map and turn to it by hand. It reads `info` and
/// never `deviceHeading`, so the needle's fifty-times-a-second redraw leaves it untouched.
struct QiblaReadout: View {
    let viewModel: QiblaViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            QiblaReadoutRow(
                label: l10n.string(.qiblaBearingLabel),
                value: l10n.degreesString(viewModel.qiblaDirection)
            )
            Divider().overlay(theme.separator)
            QiblaReadoutRow(
                label: l10n.string(.qiblaDistanceLabel),
                value: l10n.kilometresString(viewModel.distanceToKaaba)
            )

            if let coordinates = viewModel.coordinates {
                Divider().overlay(theme.separator)
                QiblaReadoutRow(
                    label: l10n.string(.onboardingLatitude),
                    value: l10n.degreesString(coordinates.latitude)
                )
                Divider().overlay(theme.separator)
                QiblaReadoutRow(
                    label: l10n.string(.onboardingLongitude),
                    value: l10n.degreesString(coordinates.longitude)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .appCard()
    }
}

/// One label-and-value pair. An `HStack` with a `Spacer`, so it mirrors for Arabic on its own —
/// the label leads, the value trails, whichever side that turns out to be.
private struct QiblaReadoutRow: View {
    let label: String
    let value: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)

            Spacer(minLength: 8)

            Text(value)
                .appFont(.callout, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

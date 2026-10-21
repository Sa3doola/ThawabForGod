//
//  MoonCard.swift
//  ThawabForGod
//

import SwiftUI

/// The selected day's moon as one element — "Moon: waxing gibbous, 79 percent illuminated,
/// 391,700 kilometres" — with the way into the full screen beside it.
struct MoonCard: View {
    let info: MoonInfo
    let hemisphere: MoonHemisphere
    let showDetails: () -> Void

    @Environment(\.theme) private var theme
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let phase = l10n.string(info.phase.labelKey)
        let percent = l10n.string(.moonPercentValue, l10n.string(Int((info.illuminatedFraction * 100).rounded())))
        let distance = l10n.string(Int(info.distanceKm.rounded()))

        VStack(alignment: .leading, spacing: 12) {
            summary(phase: phase, percent: percent, distance: distance)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                l10n.string(.moonCardAccessibility, phase, percent, l10n.string(.moonDistanceSpoken, distance))
            )

            Button(action: showDetails) {
                Label(l10n.string(.moonDetailPill), systemImage: "moon.stars")
                    .appFont(.subheadline, weight: .medium)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    /// The moon beside its words — or above them at accessibility sizes, where the words need the
    /// whole width to read as a sentence and not as "Waxing gibb…".
    @ViewBuilder
    private func summary(phase: String, percent: String, distance: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                tile(phase)
                words(phase: phase, percent: percent, distance: distance)
            }
        } else {
            HStack(spacing: 14) {
                tile(phase)
                words(phase: phase, percent: percent, distance: distance)
            }
        }
    }

    private func tile(_ phase: String) -> some View {
        MoonView(
            illuminatedFraction: info.illuminatedFraction,
            isWaxing: info.isWaxing,
            hemisphere: hemisphere,
            accessibilityText: phase
        )
        .frame(width: 56, height: 56)
        .padding(6)
        .background { DayRampBackground(stop: DayRamp.stop(for: .isha)) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func words(phase: String, percent: String, distance: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l10n.string(.calendarMoonHeading))
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
            Text(l10n.string(.calendarMoonSummary, phase, percent))
                .appFont(.body, weight: .medium)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(l10n.string(.moonDistanceValue, distance))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

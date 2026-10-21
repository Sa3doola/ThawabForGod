//
//  MoonDetailView.swift
//  ThawabForGod
//

import SwiftUI

/// The moon in full for the selected day: a large moon, its numbers, the lunar month's eight
/// phases, the next new and full moon, and a short account of how the Hijri month begins.
struct MoonDetailView: View {
    let viewModel: MoonDetailViewModel

    @Environment(\.theme) private var theme
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        let info = viewModel.info

        ScrollView {
            VStack(spacing: 20) {
                hero(info)
                stats(info)
                strip(info)
                nextEvents
                explainer
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.moonDetailTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Pieces

    private func hero(_ info: MoonInfo) -> some View {
        let phase = l10n.string(info.phase.labelKey)
        let percent = percentText(info)

        return VStack(spacing: 12) {
            MoonView(
                illuminatedFraction: info.illuminatedFraction,
                isWaxing: info.isWaxing,
                hemisphere: viewModel.hemisphere,
                accessibilityText: l10n.string(.moonAccessibilityLabel, phase, percent)
            )
            .frame(width: 200, height: 200)

            Text(phase)
                .appFont(.title2, weight: .semibold)
                .foregroundStyle(DayRamp.Ink.primary.color)

            Text(l10n.dateString(viewModel.day))
                .appFont(.subheadline)
                .foregroundStyle(DayRamp.Ink.primary.color.opacity(DayRamp.Ink.secondaryOpacity))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background { DayRampBackground(stop: DayRamp.stop(for: .isha)) }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func stats(_ info: MoonInfo) -> some View {
        HStack(alignment: .top) {
            stat(.moonDetailIlluminated, percentText(info))
            stat(.moonDetailAge, l10n.dayCountString(Int(info.ageInDays.rounded())))
            stat(.moonDetailDistance, l10n.string(.moonDistanceValue, l10n.string(Int(info.distanceKm.rounded()))))
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func stat(_ title: L10nKey, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(l10n.string(title))
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func strip(_ info: MoonInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.string(.moonPhaseStripHeading))
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(theme.textSecondary)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.phases, id: \.phase) { entry in
                        phaseButton(entry, isCurrent: entry.phase == info.phase)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func phaseButton(_ entry: MoonInfo, isCurrent: Bool) -> some View {
        let name = l10n.string(entry.phase.labelKey)

        return Button {
            viewModel.jump(to: entry.phase)
        } label: {
            VStack(spacing: 6) {
                MoonView(
                    illuminatedFraction: entry.illuminatedFraction,
                    isWaxing: entry.isWaxing,
                    hemisphere: viewModel.hemisphere,
                    accessibilityText: name
                )
                .frame(width: 44, height: 44)
                .padding(6)
                .background { DayRampBackground(stop: DayRamp.stop(for: .isha)) }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.accent, lineWidth: 2)
                    }
                }

                Text(name)
                    .appFont(.caption)
                    .foregroundStyle(isCurrent ? theme.textPrimary : theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityHint(l10n.string(.moonPhaseStripHint))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private var nextEvents: some View {
        let events = viewModel.events

        return VStack(spacing: 0) {
            eventRow(.moonNextNewMoon, events.newMoon)
            Divider().overlay(theme.separator)
            eventRow(.moonNextFullMoon, events.fullMoon)
        }
        .padding(.horizontal, 16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func eventRow(_ title: L10nKey, _ date: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.string(title))
                    .appFont(.body, weight: .medium)
                    .foregroundStyle(theme.textPrimary)
                Text(l10n.dateString(date))
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Text(l10n.daysAwayString(viewModel.daysUntil(date)))
                .appFont(.subheadline, weight: .medium)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.string(.moonExplainerTitle))
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)
            Text(l10n.string(.moonExplainerBody))
                .appFont(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func percentText(_ info: MoonInfo) -> String {
        l10n.string(.moonPercentValue, l10n.string(Int((info.illuminatedFraction * 100).rounded())))
    }
}

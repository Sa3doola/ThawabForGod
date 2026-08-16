//
//  CalculationMethodStepView.swift
//  ThawabForGod
//

import SwiftUI

/// The calculation method and Asr madhab, preselected from the user's region.
struct CalculationMethodStepView: View {
    let viewModel: OnboardingViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private var method: Binding<PrayerCalculationMethod> {
        Binding(
            get: { viewModel.state.config.method },
            set: { viewModel.select(method: $0) }
        )
    }

    private var madhab: Binding<AsrMadhab> {
        Binding(
            get: { viewModel.state.config.madhab },
            set: { viewModel.select(madhab: $0) }
        )
    }

    var body: some View {
        OnboardingScaffold(
            symbol: "slider.horizontal.3",
            title: l10n.string(.onboardingMethodTitle),
            message: l10n.string(.onboardingMethodBody)
        ) {
            VStack(alignment: .leading, spacing: 20) {
                Picker(selection: method) {
                    ForEach(PrayerCalculationMethod.allCases) { method in
                        Text(l10n.string(method.labelKey)).tag(method)
                    }
                } label: {
                    Text(l10n.string(.methodLabel))
                }
                // A menu, not a wheel: twelve long names need the room, and it is the one
                // picker style that reads well on both iOS and macOS.
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.string(.madhabLabel))
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(theme.textPrimary)

                    Picker(selection: madhab) {
                        ForEach(AsrMadhab.allCases) { madhab in
                            Text(l10n.string(madhab.labelKey)).tag(madhab)
                        }
                    } label: {
                        Text(l10n.string(.madhabLabel))
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }
}

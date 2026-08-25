//
//  ManualLocationSheet.swift
//  ThawabForGod
//

import SwiftUI

/// Latitude and longitude by hand — the way out when location is refused, and the way to
/// correct a fix that landed in the wrong city.
///
/// Not a city search, for the same reason onboarding's is not: resolving a place name needs the
/// network, and no core screen in this app may depend on that. The field labels are onboarding's
/// own keys, because "Latitude" is the same word on both screens and a second copy would be one
/// more string to keep translated.
struct ManualLocationSheet: View {
    let viewModel: QiblaViewModel
    let coordinator: QiblaCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(l10n.string(.onboardingManualTitle))
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)

                HStack(spacing: 12) {
                    CoordinateField(
                        title: l10n.string(.onboardingLatitude),
                        value: latitude
                    )
                    CoordinateField(
                        title: l10n.string(.onboardingLongitude),
                        value: longitude
                    )
                }

                Button {
                    if viewModel.applyManualCoordinates() {
                        coordinator.finishEditingLocation()
                    }
                } label: {
                    Text(l10n.string(.onboardingManualSave))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                // Nothing to save until both fields hold a real point on the globe.
                .disabled(!viewModel.manualCoordinatesAreValid)

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background)
            .navigationTitle(l10n.string(.qiblaSetLocation))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.string(.qiblaDone)) {
                        coordinator.finishEditingLocation()
                    }
                }
            }
        }
    }

    // The view model owns the typed text so a half-finished number survives the sheet being
    // scrolled or the keyboard changing; these just hand SwiftUI a way to write it.
    private var latitude: Binding<String> {
        Binding(get: { viewModel.manualLatitude }, set: { viewModel.manualLatitude = $0 })
    }

    private var longitude: Binding<String> {
        Binding(get: { viewModel.manualLongitude }, set: { viewModel.manualLongitude = $0 })
    }
}

private struct CoordinateField: View {
    let title: String
    @Binding var value: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)

            TextField(title, text: $value)
                .textFieldStyle(.roundedBorder)
                .appFont(.body)
                // A coordinate is a signed decimal, so the sign and separator have to be
                // reachable — `.decimalPad` offers neither.
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
                .accessibilityLabel(title)
        }
    }
}

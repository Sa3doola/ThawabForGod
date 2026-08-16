//
//  LocationStepView.swift
//  ThawabForGod
//

import SwiftUI

/// Asks for location, and degrades into manual entry the moment the answer is no.
///
/// The refusal path is not an error state — it is a second, equally supported way to give the
/// app a position, which is what keeps the offline promise honest for a user who will not
/// share location at all.
struct LocationStepView: View {
    let viewModel: OnboardingViewModel

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        OnboardingScaffold(
            symbol: "location.circle",
            title: l10n.string(.onboardingLocationTitle),
            message: l10n.string(.onboardingLocationBody)
        ) {
            switch viewModel.state.location {
            case .granted where viewModel.state.hasLocation:
                OnboardingConfirmation(message: l10n.string(.onboardingLocationGranted))

            // Granted but no fix yet, or refused: either way the user needs a way to say
            // where they are.
            case .granted, .denied:
                ManualCoordinatesForm(viewModel: viewModel)

            case .notRequested, .skipped:
                requestButton
            }
        }
    }

    private var requestButton: some View {
        Button {
            Task { await viewModel.requestLocationPermission() }
        } label: {
            Text(l10n.string(.onboardingLocationAllow))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isRequestingPermission)
    }
}

/// Latitude and longitude by hand. Not a city search: resolving a name needs the network,
/// and no core screen in this app may depend on that.
private struct ManualCoordinatesForm: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.state.location == .denied {
                Text(l10n.string(.onboardingLocationDeniedBody))
                    .appFont(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(l10n.string(.onboardingManualTitle))
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            HStack(spacing: 12) {
                CoordinateField(
                    title: l10n.string(.onboardingLatitude),
                    value: $viewModel.manualLatitude
                )
                CoordinateField(
                    title: l10n.string(.onboardingLongitude),
                    value: $viewModel.manualLongitude
                )
            }

            if viewModel.state.hasLocation {
                OnboardingConfirmation(message: l10n.string(.onboardingManualSaved))
            }

            Button {
                viewModel.applyManualCoordinates()
            } label: {
                Text(l10n.string(.onboardingManualSave))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            // Nothing to save until both fields hold a real point on the globe.
            .disabled(!viewModel.manualCoordinatesAreValid)
        }
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

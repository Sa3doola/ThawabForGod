//
//  QiblaView.swift
//  ThawabForGod
//

import SwiftUI

/// Which way to face, on whatever hardware is running the app.
///
/// The body is a `switch` over one status, and each branch is a complete screen rather than a
/// pile of conditionally-hidden pieces. That is what keeps "this Mac has no magnetometer" from
/// reading as a degraded phone screen: it is simply the readout, on purpose.
struct QiblaView: View {
    let viewModel: QiblaViewModel
    let coordinator: QiblaCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                content
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.qiblaTitle))
        // The feed's lifetime is this task's: SwiftUI cancels it on disappear, the stream
        // finishes, and `CoreLocationHeadingProvider` stops the magnetometer.
        .task { await viewModel.start() }
        .sheet(isPresented: isEditingLocation) {
            ManualLocationSheet(viewModel: viewModel, coordinator: coordinator)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .locating:
            QiblaNotice(message: l10n.string(.qiblaLocating), showsProgress: true)

        case .permissionDenied:
            QiblaNotice(message: l10n.string(.qiblaLocationNeededBody), showsProgress: false)
            setLocationButton
                .buttonStyle(.borderedProminent)

        case .ready, .needsCalibration:
            CompassDial(viewModel: viewModel)

            if viewModel.status == .needsCalibration {
                QiblaHint(message: l10n.string(.qiblaCalibrationHint), symbol: "figure.walk.motion")
            }

            QiblaReadout(viewModel: viewModel)
            setLocationButton

        case .headingUnavailable:
            // First-class, not an error: the bearing below is exact, there is simply no
            // magnetometer to animate a needle against.
            QiblaHint(message: l10n.string(.qiblaCompassUnavailable), symbol: "location.north.line")
            QiblaReadout(viewModel: viewModel)
            setLocationButton
        }
    }

    private var setLocationButton: some View {
        Button {
            coordinator.editLocation()
        } label: {
            Text(l10n.string(.qiblaSetLocation))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    /// The sheet's presentation lives on the coordinator, which exposes it read-only — so the
    /// binding is built here rather than reached for with `@Bindable`, and dismissal by swipe
    /// goes through the same method a Done button would call.
    private var isEditingLocation: Binding<Bool> {
        Binding(
            get: { coordinator.isEditingLocation },
            set: { if !$0 { coordinator.finishEditingLocation() } }
        )
    }
}

/// The waiting and no-position states, which differ only by a spinner.
private struct QiblaNotice: View {
    let message: String
    let showsProgress: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            if showsProgress {
                ProgressView()
            }
            Text(message)
                .appFont(.callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

/// A short explanation that sits above the readout — the missing-magnetometer note and the
/// calibration prompt are the same shape, so they are the same view.
private struct QiblaHint: View {
    let message: String
    let symbol: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(theme.accent)
            Text(message)
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .appCard(radius: AppRadius.md)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        QiblaView(
            viewModel: QiblaViewModel(
                getQiblaInfo: GreatCircleQiblaInfoUseCase(engine: PrayerTimeEngine()),
                locationService: CoreLocationService(settingsStore: settingsStore),
                headingProvider: CoreLocationHeadingProvider(),
                coordinates: Coordinates(latitude: 51.5074, longitude: -0.1278)
            ),
            coordinator: QiblaCoordinator()
        )
    }
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}

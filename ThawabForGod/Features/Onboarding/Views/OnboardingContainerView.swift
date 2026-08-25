//
//  OnboardingContainerView.swift
//  ThawabForGod
//

import SwiftUI

/// Composes the four steps: progress at the top, the current step in the middle, navigation
/// at the bottom.
///
/// A `switch` over `OnboardingStep` rather than a `NavigationStack` of pushes — the flow is
/// linear and the container owns which screen is showing, which keeps each step view a leaf
/// that knows nothing about the ones on either side of it.
struct OnboardingContainerView: View {
    let viewModel: OnboardingViewModel
    let coordinator: OnboardingCoordinator

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingProgress(currentStep: viewModel.step)

            ScrollView {
                currentStep
                    .padding(.vertical, 8)
            }

            OnboardingNavigation(viewModel: viewModel, coordinator: coordinator)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.background)
        // Keyed by step so SwiftUI treats each screen as a new view and animates the change
        // rather than cross-fading the fields of one into another.
        .animation(.snappy, value: viewModel.step)
    }

    @ViewBuilder
    private var currentStep: some View {
        switch viewModel.step {
        case .welcome:
            WelcomeStepView()
        case .location:
            LocationStepView(viewModel: viewModel)
        case .notifications:
            NotificationsStepView(viewModel: viewModel)
        case .method:
            CalculationMethodStepView(viewModel: viewModel)
        case .done:
            // The router swaps this view out the moment onboarding finishes; this is only
            // ever on screen for the frame in between.
            EmptyView()
        }
    }
}

/// One dot per screen. No numbers, so nothing here needs digit localization.
private struct OnboardingProgress: View {
    let currentStep: OnboardingStep

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.visibleSteps) { step in
                Capsule()
                    .fill(step == currentStep ? theme.accent : theme.separator)
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
            }
        }
        .animation(.snappy, value: currentStep)
        .accessibilityHidden(true)
    }
}

/// Back, skip and continue. Which of them appear is a property of the step, not of the layout.
private struct OnboardingNavigation: View {
    let viewModel: OnboardingViewModel
    let coordinator: OnboardingCoordinator

    @Environment(LocalizationManager.self) private var l10n

    private var isLastStep: Bool { viewModel.step.next == .done }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                coordinator.advance()
            } label: {
                Text(l10n.string(isLastStep ? .onboardingFinish : .onboardingContinue))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack {
                if viewModel.canGoBack {
                    Button(l10n.string(.onboardingBack)) { coordinator.back() }
                }

                Spacer()

                // Only the permission screens can be passed without answering — the app is
                // built to run without either grant, so pretending otherwise would be a lie.
                if viewModel.step.isSkippable {
                    Button(l10n.string(.onboardingSkip)) { coordinator.skip() }
                }
            }
            .appFont(.callout)
        }
    }
}

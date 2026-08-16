//
//  OnboardingCoordinator.swift
//  ThawabForGod
//

import Observation
import SwiftUI

/// Owns the movement between onboarding screens, and reports when the flow is over.
///
/// The view model decides *what* the next step is; this decides how the screens are presented
/// and tells the app router when to hand over to Home. Keeping the two apart is what lets the
/// step machine be unit-tested without any navigation at all.
@Observable
@MainActor
final class OnboardingCoordinator {
    private let viewModel: OnboardingViewModel
    private let onFinished: () -> Void

    /// The direction the last move went, so the transition slides the way the user expects
    /// under both layout directions.
    private(set) var isMovingForward = true

    init(viewModel: OnboardingViewModel, onFinished: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onFinished = onFinished
    }

    func advance() {
        isMovingForward = true
        viewModel.advance()
        notifyIfFinished()
    }

    func skip() {
        isMovingForward = true
        viewModel.skip()
        notifyIfFinished()
    }

    func back() {
        isMovingForward = false
        viewModel.back()
    }

    private func notifyIfFinished() {
        guard viewModel.isFinished else { return }
        onFinished()
    }
}

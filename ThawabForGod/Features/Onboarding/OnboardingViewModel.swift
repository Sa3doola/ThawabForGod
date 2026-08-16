//
//  OnboardingViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the first run: which screen is showing, what the user has answered, and what gets
/// persisted at the end.
///
/// The guiding rule from the plan is that **no permission is ever load-bearing**. Every path
/// through here reaches `.done`, whether the user grants location, refuses it and types
/// coordinates, or skips both screens outright.
@Observable
@MainActor
final class OnboardingViewModel {
    private(set) var state: OnboardingState

    /// Set while a permission prompt is in flight, so the button can disable itself rather
    /// than let a second tap strand the first request.
    private(set) var isRequestingPermission = false

    /// Raw text from the manual-entry fields, kept as typed so a half-finished number is not
    /// thrown away mid-keystroke. Parsed on submit.
    var manualLatitude = ""
    var manualLongitude = ""

    @ObservationIgnored private let locationService: any LocationService
    @ObservationIgnored private let notificationService: any NotificationService
    @ObservationIgnored private let completeOnboarding: CompleteOnboardingUseCase
    @ObservationIgnored private let tips: any OnboardingTipReporting

    init(
        locationService: any LocationService,
        notificationService: any NotificationService,
        completeOnboarding: CompleteOnboardingUseCase,
        tips: any OnboardingTipReporting = OnboardingTipReporter(),
        locale: Locale = .autoupdatingCurrent
    ) {
        self.locationService = locationService
        self.notificationService = notificationService
        self.completeOnboarding = completeOnboarding
        self.tips = tips
        self.state = OnboardingState(
            config: CalculationConfig(
                method: .recommended(for: locale),
                madhab: .shafi
            )
        )
    }

    // MARK: Step machine

    var step: OnboardingStep { state.step }

    var isFinished: Bool { state.step == .done }

    var canGoBack: Bool { state.step.previous != nil }

    /// Moves to the next screen, finishing if this was the last one.
    func advance() {
        guard let next = state.step.next else { return }

        if next == .done {
            finish()
        } else {
            state.step = next
        }
    }

    func back() {
        guard let previous = state.step.previous else { return }
        state.step = previous
    }

    /// Steps past a permission screen without answering it.
    func skip() {
        guard state.step.isSkippable else { return }

        switch state.step {
        case .location where state.location == .notRequested:
            state.location = .skipped
        case .notifications where state.notifications == .notRequested:
            state.notifications = .skipped
        default:
            break
        }

        advance()
    }

    // MARK: Permissions

    /// Asks for location, and on success reads a position straight away so the manual-entry
    /// fallback is never shown to a user who has already granted access.
    func requestLocationPermission() async {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let outcome = await locationService.requestWhenInUseAuthorization()

        guard outcome == .authorized else {
            state.location = .denied
            return
        }

        state.location = .granted
        // A granted permission that yields no fix is still a granted permission — the user
        // can supply coordinates by hand, and the app carries on either way.
        state.coordinates = try? await locationService.currentCoordinates()
    }

    func requestNotificationPermission() async {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        state.notifications = await notificationService.requestAuthorization() == .authorized
            ? .granted
            : .denied
    }

    // MARK: Manual location

    /// Whether what has been typed so far is a real point on the globe.
    var manualCoordinatesAreValid: Bool {
        parsedManualCoordinates != nil
    }

    private var parsedManualCoordinates: Coordinates? {
        guard let latitude = Double(manualLatitude.trimmingCharacters(in: .whitespaces)),
              let longitude = Double(manualLongitude.trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }

        return Coordinates(latitude: latitude, longitude: longitude)
    }

    /// Accepts typed coordinates. Returns whether they were usable, so the view can keep the
    /// user on the field instead of silently doing nothing.
    @discardableResult
    func applyManualCoordinates() -> Bool {
        guard let coordinates = parsedManualCoordinates else { return false }

        state.coordinates = coordinates
        return true
    }

    // MARK: Calculation choices

    func select(method: PrayerCalculationMethod) {
        state.config.method = method
    }

    func select(madhab: AsrMadhab) {
        state.config.madhab = madhab
    }

    // MARK: Finishing

    private func finish() {
        completeOnboarding(state: state)

        // Only recordable at this instant, so it is donated even though the tip it feeds is
        // not on screen anywhere yet — see `OnboardingTips`.
        tips.onboardingCompleted()

        state.step = .done
    }
}

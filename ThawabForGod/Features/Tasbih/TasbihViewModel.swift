//
//  TasbihViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives both tasbih screens: the list of presets, and the counter for the one being counted.
///
/// **Counting is a main-actor value; saving is a trip to a database.** Those two happen at very
/// different rates, and keeping them apart is most of this type's job. A tap moves an `Int` in
/// memory and nothing else — no `await`, no context, nothing that can make a finger feel slow.
/// The store is written at the three moments that actually matter:
///
/// - a lap completes, which is the natural checkpoint and the only one a user would notice losing
/// - the screen goes away, or the app leaves the foreground
/// - the counter is reset, or another preset is chosen
///
/// The cost of that choice is bounded and worth naming: kill the app mid-lap and the taps since
/// the last checkpoint are gone. Saving on every tap would trade a guaranteed hitch on a
/// hundred-tap dhikr for a loss nobody has ever complained about.
@Observable
@MainActor
final class TasbihViewModel {

    /// What the preset list has to show.
    enum PresetsPhase: Equatable {
        case loading
        case ready([TasbihDhikr])
        /// The corpus could not be read — a packaging fault, not something the user did.
        case unavailable
    }

    // MARK: State

    private(set) var presetsPhase: PresetsPhase = .loading

    /// The preset being counted, and the live progress through it.
    ///
    /// One property rather than four loose numbers, so the count, the target and the lap tally
    /// can never disagree about which dhikr they describe.
    private(set) var session: TasbihSession?
    private(set) var dhikr: TasbihDhikr?

    /// Whether taps have been made that the store has not seen yet.
    ///
    /// Not private: it is the honest name for "there is something to lose", the view reads it to
    /// know whether leaving needs a save, and the tests assert on it directly.
    private(set) var hasUnsavedCount = false

    @ObservationIgnored private let useCase: TasbihUseCase
    @ObservationIgnored private let tips: any TasbihTipReporting
    @ObservationIgnored private let now: @Sendable () -> Date

    init(
        useCase: TasbihUseCase,
        tips: any TasbihTipReporting = TasbihTipReporter(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.useCase = useCase
        self.tips = tips
        self.now = now
    }

    // MARK: Derived

    var currentCount: Int { session?.currentCount ?? 0 }
    var targetCount: Int { session?.targetCount ?? 0 }
    var completedLaps: Int { session?.completedLaps ?? 0 }

    /// Recitations including finished laps. Monotonic across a lap boundary, unlike
    /// `currentCount`, which is what makes it the right trigger for one haptic per tap.
    var totalCount: Int { session?.totalCount ?? 0 }

    /// How far into the current lap, as a fraction. Clamped, so a session restored with a count
    /// past a target that shrank cannot overfill the ring.
    var lapProgress: Double {
        guard targetCount > 0 else { return 0 }
        return min(1, Double(currentCount) / Double(targetCount))
    }

    // MARK: Loading

    func loadPresets(in language: AppLanguage) async {
        presetsPhase = .loading

        do {
            let presets = try await useCase.presets(in: language)
            guard !Task.isCancelled else { return }
            presetsPhase = .ready(presets)
        } catch {
            guard !Task.isCancelled else { return }
            presetsPhase = .unavailable
        }
    }

    /// Opens a preset, restoring whatever was counted for it before.
    ///
    /// Flushes the outgoing preset's pending taps first: moving between two dhikr is exactly the
    /// kind of thing that would otherwise drop a half-finished lap on the floor.
    func select(_ dhikr: TasbihDhikr) async {
        if self.dhikr?.id != dhikr.id {
            await persistPendingCount()
        }

        self.dhikr = dhikr

        do {
            let session = try await useCase.session(for: dhikr)
            guard !Task.isCancelled else { return }
            self.session = session
            hasUnsavedCount = false
        } catch {
            guard !Task.isCancelled else { return }
            // A store that cannot be read is not a reason to refuse to count. Starting fresh in
            // memory means the screen still works; the save on the way out will try again.
            self.session = TasbihSession.starting(dhikr, now: now())
            hasUnsavedCount = false
        }
    }

    // MARK: Counting

    /// Records one recitation. Synchronous by design — a tap must not wait on a database.
    func increment() {
        guard let session else { return }

        let outcome = TasbihUseCase.counting(session, now: now())
        self.session = outcome.session
        hasUnsavedCount = true

        tips.counted()

        if outcome.completedLap {
            // A checkpoint worth keeping. Unstructured on purpose: the write has to outlive
            // whatever redraw the tap kicked off, and there is no view whose lifetime it belongs
            // to. It is a hop to the model actor and back — nothing that would hold a frame.
            Task { await persistPendingCount() }
        }
    }

    /// Clears the current preset's progress, in memory and in the store.
    func reset() async {
        guard let dhikr else { return }

        hasUnsavedCount = false
        tips.resetPerformed()

        do {
            session = try await useCase.reset(dhikr)
        } catch {
            // The row could not be deleted. Zeroing what is on screen is still the right thing:
            // the user asked, and the next save will overwrite the stale row anyway.
            session = TasbihSession.starting(dhikr, now: now())
        }
    }

    // MARK: Persistence

    /// Writes the live count, if there is anything to write.
    ///
    /// Idempotent and cheap to call — the view leans on that, firing it from both `onDisappear`
    /// and a scene-phase change without either having to know the other exists.
    func persistPendingCount() async {
        guard hasUnsavedCount, let session else { return }

        // Cleared before the await, not after: a tap arriving mid-save marks the session dirty
        // again, and clearing afterwards would wipe that flag and lose it.
        hasUnsavedCount = false

        do {
            try await useCase.save(session)
        } catch {
            // Nothing to tell the user — they are counting, not filing. Marked dirty again so
            // the next checkpoint retries rather than assuming the count is safe.
            hasUnsavedCount = true
        }
    }
}

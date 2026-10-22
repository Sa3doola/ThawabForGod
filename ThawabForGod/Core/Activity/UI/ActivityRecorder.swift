//
//  ActivityRecorder.swift
//  ThawabForGod
//

import Foundation

/// Records where the user got to, without writing on every tap.
///
/// The three features that report activity report it at very different rates: the Quran once per
/// verse the reader stops on, the adhkar once per recitation counted, the tasbih once per tap.
/// Left alone, a hundred-count dhikr would be a hundred SwiftData saves for one number that only
/// the last value of ever matters.
///
/// So each kind gets one pending write, replaced whenever a newer one arrives, landing shortly
/// after the taps stop. `flush()` writes anything still waiting — a screen being left is exactly
/// when the last value matters and exactly when the delay would lose it.
///
/// One recorder shared by the three view models, with a pending write *per kind*, so a tasbih tap
/// cannot cancel an adhkar count that was waiting to land.
@MainActor
final class ActivityRecorder {
    private let useCase: RecentActivityUseCase
    private let delay: Duration

    private var pending: [ActivityKind: RecentActivity] = [:]
    private var tasks: [ActivityKind: Task<Void, Never>] = [:]

    /// The store write for each kind that has left `pending` but not yet finished. `write(_:)`
    /// takes the entry out of `pending` before it awaits the save, so without this a `flush()`
    /// arriving mid-save would find nothing waiting and return while the write was still going.
    private var saving: [ActivityKind: Task<Void, Never>] = [:]

    /// - Parameter delay: how long the taps have to stop before the write goes out. Injected so a
    ///   test can drive the debounce without waiting on it.
    init(useCase: RecentActivityUseCase, delay: Duration = .milliseconds(400)) {
        self.useCase = useCase
        self.delay = delay
    }

    func record(_ activity: RecentActivity) {
        pending[activity.kind] = activity
        tasks[activity.kind]?.cancel()

        tasks[activity.kind] = Task { [weak self] in
            guard let self, (try? await Task.sleep(for: delay)) != nil else { return }
            await write(activity.kind)
        }
    }

    /// Writes everything still waiting. Driven from a screen's `onDisappear`.
    func flush() async {
        for kind in Array(pending.keys) {
            tasks[kind]?.cancel()
            tasks[kind] = nil
            await write(kind)
        }

        // Writes the timer had already started: not in `pending` any more, but not on disk yet.
        for save in Array(saving.values) {
            await save.value
        }
    }

    private func write(_ kind: ActivityKind) async {
        guard let activity = pending.removeValue(forKey: kind) else { return }

        tasks[kind] = nil

        // Behind any earlier save of the same kind, so two writes cannot land out of order.
        let earlier = saving[kind]
        let save = Task { [useCase] in
            await earlier?.value
            await useCase.record(activity)
        }
        saving[kind] = save

        await save.value

        if saving[kind] == save { saving[kind] = nil }
    }
}

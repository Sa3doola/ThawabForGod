//
//  TipsSettingsViewModel.swift
//  ThawabForGod
//

import Observation

/// Brings dismissed tips back.
///
/// The one piece of screen state in the whole of Settings that belongs to a screen rather than to
/// a manager — and it earns its place. TipKit reads its datastore when `Tips.configure` runs at
/// launch, so wiping it mid-session changes nothing visible; a row that silently did nothing
/// would read as broken, so the screen has to say what happened instead.
@Observable
@MainActor
final class TipsSettingsViewModel {

    private(set) var hasResetTips = false

    @ObservationIgnored private let resetTips: ResetTipsUseCase

    init(resetTips: ResetTipsUseCase) {
        self.resetTips = resetTips
    }

    func resetTipsTapped() {
        resetTips()
        hasResetTips = true
    }
}

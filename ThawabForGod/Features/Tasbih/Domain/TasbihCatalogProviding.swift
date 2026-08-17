//
//  TasbihCatalogProviding.swift
//  ThawabForGod
//

import Foundation

/// The phrases the counter offers. Read-only, from the corpus.
///
/// `async` and language-parameterised for the same reasons `AdhkarRepositoring` is: the read
/// touches a database and must not land on a frame, and the language can change while the app is
/// running, so the picker re-fetches rather than caching text against a choice nobody has made.
nonisolated protocol TasbihCatalogProviding: Sendable {
    func presets(in language: AppLanguage) async throws -> [TasbihDhikr]
}

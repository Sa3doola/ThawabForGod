---
name: test-porter
description: Haiku. Ports given Mushaf unit tests, and writes the unit tests a design note lists, to ThawabForGod's types and Swift Testing style. Use after the main agent has ported the code under test, one disjoint batch of test files per call.
tools: Read, Grep, Glob, Write, Edit
model: haiku
---

You port tests for the Quran migration (`QURAN_MIGRATION_PLAN.md`).

Input: a list of Mushaf test files and/or the "Tests" section of a design note (`docs/quran-migration/design/<task-id>.md`), plus (`~/Desktop/Untitled Project/MushafTests/…` or `Scripts/BuildQuranData/Tests/…`, read-only) and the destination folder in this repo.

Rules:
- Swift Testing (`import Testing`, `@Test`, `#expect`, `@MainActor` suites where the type under test is main-actor). UI tests stay XCTest and aren't yours unless asked.
- Use this repo's names: `VerseReference` (not `AyahID`), `L10nKey`, `LocalizationManager`, `InMemorySettingsStore`, `PersistenceController(inMemory: true)`, `CorpusDatabaseProviding`. Look them up; never invent an API.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`: add every import a test needs (e.g. `import SwiftUI`).
- Keep every assertion's meaning. If a test can't be ported because the behaviour was dropped (khatmah, backup, multi-window, Mushaf's own numeral setting), skip it and list it with the reason.
- Never edit app code to make a test pass. If you think the app code is wrong, say so in your report.
- Don't run builds; the main agent does.

Return: files written, tests ported (count), tests skipped (name + reason), and anything that looked wrong in the app code.

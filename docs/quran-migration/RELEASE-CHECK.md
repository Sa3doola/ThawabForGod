# Release check (M8.3), 2026-10-21

Branch `quran-migration`. Checked on Xcode 27.1 (iOS 27.0 simulator runtime, macOS). Every number below
was measured in this session; what was not measured is listed at the end.

## 1. Nothing QUL-derived is tracked

- `git ls-files` filtered for the QUL names (`quran-mushaf`, `madaniV2`, `QuranData/raw|out|Fonts`,
  `surah-name-v2`, `surah-header`, `quran-common`, the four QUL packs) finds only a README
  (`QuranData/Fonts/madaniV2/README.md`), a hash list (`QuranData/fonts-v2.sha256`), the builder source
  (`QULCorpus.swift`) and a profile config (`qul.json`). No data, font or pack.
- `git status --porcelain --ignored` lists 628 ignored paths: the page fonts, `QuranData/raw` and `out`,
  `quran-mushaf.sqlite`, the QUL packs, and `Screenshots/quran-migration/` (the widget PNGs).
- `rules-checker` ran on the B1-B4 fix commits and on the M8.2/M8.3 docs commit and found no staged QUL file; it did not run on every small commit.

## 2. A public clone builds and runs; a public Release build is refused (by design)

A clean `git worktree` of HEAD has none of the ignored data, which is exactly a public clone.

| Build | Result |
|---|---|
| Debug, macOS | builds; the "Check Quran full data" phase prints its warning only |
| Debug, iOS simulator | builds; same warning |
| **Release**, macOS | **fails**: "the full Quran data is missing ... A Release build must ship the full data." |
| **Release**, iOS simulator | **fails**, same message |

So the App Store build cannot be produced from a public clone: the guard in
`Tools/add_quran_data_phase.rb` works. Public Debug size (the Tanzil profile: `quran.sqlite`,
Jalalayn, Hadith, adhkar, fonts):

| | Installed | Deflated (zip of the `.app`) |
|---|---|---|
| macOS, public, Debug | 76 MB | 20.7 MB |
| iOS simulator, public, Debug | 88 MB | 30.0 MB |

## 3. Size of the full-data build against the 200 MB budget (T6)

Release builds from the working tree with the full data (`.app` bundles, deflated with `ditto -c -k`,
a proxy for the download; an archive would also thin the binary):

| | Installed | Deflated | Budget (compressed / installed) |
|---|---|---|---|
| macOS, full, Release | 279 MB | **154.3 MB** | 200 MB / 400 MB: **within** |
| iOS simulator, full, Release | 289 MB | **162.9 MB** | 200 MB / 400 MB: **within** |

The builder also enforces the budget on what it installs and fails over it
(`Tools/QuranBuilder`, `SizeReport`). Headroom is about 37-46 MB compressed.

## 4. Offline

Static proof, not a run with the network off:

- No `URLSession`, `HTTPClient`, `NWPathMonitor`, `ReachabilityMonitor` or URL literal in
  `Features/Quran`, `Shared/Quran`, `Shared/Widgets`, `NoorWidgets` or `Packages`.
- The Mac app's entitlements carry no network entitlement, so the sandboxed app cannot connect at all
  (the iOS app has no such switch; there the proof is the absence of network code above).
- All Quran data (text, layout, fonts, packs, the ayah-of-the-day list) is bundled.

## 5. Licence status (what blocks an App Store release, not the merge)

From `docs/release/license-requests.md` (sent 2026-10-20, no replies recorded yet) and
`ThawabForGod/Resources/Licenses/`:

| Item | Status |
|---|---|
| QUL resources (layout, V2 page fonts, three faces, Saheeh International, Al-Muyassar, Al-Mukhtasar, surah info) | **Unconfirmed; requested.** Not in the repository. They ship only in an App Store build once answered in writing. |
| KFGQPC HAFS font | EULA allows free distribution unmodified; the licence text is bundled and shown in Settings → Sources. |
| Amiri Quran, IBM Plex Sans Arabic | OFL; texts bundled and shown in Settings → Sources. |
| Tanzil text | CC BY 3.0, no changes; notice bundled (`TanzilQuranText-NOTICE.txt`, copied from the database's own `meta` rows) and shown in Settings → Sources **in the public build only** (a full-data build replaces the Tanzil row with the KFGQPC/QUL row, which has no licence file yet). |
| Tafsir al-Jalalayn | Public domain by age; notice bundled (`TafsirAlJalalayn-NOTICE.txt`). **Not yet a Settings → Sources row** (it would need two new strings). |
| Hadith (Bukhari, Muslim) | Public-domain narrations from an Unlicense mirror; **no licence text file yet** in `Resources/Licenses/`. |
| Adhkar, 99 names | **Unsettled** (see the Corpus README; unchanged by this migration). |

No licence-TODO marker remains in any source file.

## 6. Not verified here

- A run with the network actually disabled.
- A signed archive and its real `.ipa` size; the Mac App Group container on a signed build
  (`SharedDefaults` uses the plain group id; `CLAUDE.md` says the Mac needs the team prefix).
- The widgets on a real Home Screen or Mac desktop. (A widget was seen rendering on this Mac's desktop
  during testing, with the Ayah of the Day in Arabic and Saheeh International; that is one look, not a check.)

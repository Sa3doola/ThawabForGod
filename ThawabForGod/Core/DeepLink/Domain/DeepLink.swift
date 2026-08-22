//
//  DeepLink.swift
//  ThawabForGod
//

import Foundation

/// Somewhere outside the app can send the reader.
///
/// The app already has `AppRoute`, and this is deliberately not it. Two reasons, and the second
/// is the one that matters.
///
/// `AppRoute` carries `AdhkarCategory` and `VerseReference` — types that live in feature Domain
/// folders and stay there. A widget process cannot see them without dragging half the app across
/// the target boundary.
///
/// More importantly the two have different lifetimes. `AppRoute` is internal wiring and may be
/// reshaped whenever the features behind it are. A `DeepLink` is a *promise*: once
/// `noor://qibla` is sitting in somebody's Home Screen shortcut or baked into a widget the system
/// has cached, it has to keep meaning what it meant. So the external vocabulary is small,
/// stable and stated once here, and one place at the composition root translates it into
/// whatever the app's internals happen to look like today — see `AppContainer.open(_:)`.
///
/// Every case is reachable by URL and every URL round-trips. Nothing about parsing one can trap:
/// the input arrives from outside the app, so an unknown host, a missing query or a malformed
/// string is an answer of `nil` rather than a crash.
nonisolated enum DeepLink: Hashable, Sendable {

    /// Home, as the reader last left it.
    case home

    /// Home, with the day's schedule sheet already up.
    case prayerTimes

    case qibla
    case tasbih
    case names

    /// The adhkar list, at its categories.
    case adhkar

    /// One category of adhkar, open.
    ///
    /// A separate case rather than `adhkar(Period?)` so that neither call sites nor a `switch`
    /// have to carry an optional whose `nil` means something entirely different from its `some`.
    case adhkarCategory(Period)

    /// The Mushaf, wherever reading stopped.
    case quran

    case hadith

    /// Settings. On macOS this is a no-op — that build reaches the same screen through ⌘, and
    /// has no Settings tab for a link to select.
    case settings

    /// The adhkar categories, named in the link's own vocabulary rather than the feature's.
    ///
    /// `AdhkarCategory` is the app's type and its raw values are corpus row ids; if the corpus
    /// ever renames one, every shortcut anybody has saved would break. This enum is the promise,
    /// and `AppContainer.open(_:)` is where the two are reconciled.
    nonisolated enum Period: String, CaseIterable, Sendable {
        case morning
        case evening
    }
}

// MARK: - URLs

/// `nonisolated` explicitly, and it matters more here than almost anywhere else in the app: the
/// module default is `MainActor`, a bare `extension` does not inherit the type's own
/// `nonisolated`, and a widget's timeline provider builds these URLs off the main actor.
nonisolated extension DeepLink {

    /// The one scheme, declared in `Info.plist` under `CFBundleURLTypes`.
    static let scheme = "noor"

    /// The query item that carries a category, for the one link that has a payload.
    private static let periodQueryName = "period"

    /// The host for this destination. Kebab-case, because that is what reads as a URL.
    private var host: String {
        switch self {
        case .home: "home"
        case .prayerTimes: "prayer-times"
        case .qibla: "qibla"
        case .tasbih: "tasbih"
        case .names: "names"
        case .adhkar, .adhkarCategory: "adhkar"
        case .quran: "quran"
        case .hadith: "hadith"
        case .settings: "settings"
        }
    }

    /// This destination as a URL.
    ///
    /// Not optional: every case above produces a host that is a valid authority and a query that
    /// is either absent or a single well-formed item, so `URLComponents` cannot fail to build
    /// one. The `preconditionFailure` is unreachable and says so — an optional here would push a
    /// `!` or a `??` onto every widget and every shortcut item instead.
    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = host

        if case .adhkarCategory(let period) = self {
            components.queryItems = [
                URLQueryItem(name: Self.periodQueryName, value: period.rawValue)
            ]
        }

        guard let url = components.url else {
            preconditionFailure("DeepLink.\(self) produced components that are not a URL")
        }

        return url
    }

    /// Reads a URL the system handed us, or `nil` if it names nothing this app knows.
    ///
    /// Everything here is defensive on purpose. The input comes from outside the process — a
    /// widget the system cached under an older build, a shortcut somebody saved two releases
    /// ago, or a URL typed by hand — so the failure mode has to be "ignored", never "crashed"
    /// and never "opened the wrong screen".
    ///
    /// The scheme and host are lowercased before matching because URL hosts are
    /// case-insensitive by definition and `NOOR://Qibla` is the same link.
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.scheme,
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }

        switch host {
        case "home": self = .home
        case "prayer-times": self = .prayerTimes
        case "qibla": self = .qibla
        case "tasbih": self = .tasbih
        case "names": self = .names
        case "quran": self = .quran
        case "hadith": self = .hadith
        case "settings": self = .settings

        case "adhkar":
            // No period is the list; an unrecognised one is *also* the list rather than nothing,
            // because a link that names a category this build has not shipped yet still clearly
            // means "the adhkar". Dropping it entirely would strand the reader on Home.
            let raw = components.queryItems?
                .first { $0.name == Self.periodQueryName }?
                .value

            if let raw, let period = Period(rawValue: raw.lowercased()) {
                self = .adhkarCategory(period)
            } else {
                self = .adhkar
            }

        default:
            return nil
        }
    }
}

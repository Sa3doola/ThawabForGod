//
//  PlaceNameResolving.swift
//  ThawabForGod
//

import Foundation

/// Turns a point on the globe into the name of the place it is in.
///
/// **The one part of the location story that needs the network**, and therefore the one part
/// nothing may depend on. Coordinates come from GPS and work with the radio off; a *city name*
/// is reverse geocoding, which is a request to a server. The architecture plan calls the name
/// cosmetic and says never to block on it, so this protocol is shaped to make blocking awkward:
/// it returns an optional rather than throwing, because "no name" is an ordinary Tuesday and not
/// an error anybody can act on.
///
/// It lives beside `LocationService` rather than inside it deliberately. That protocol's own
/// documentation rules place names out of scope precisely so the offline promise is legible in
/// its signature, and folding them back in would blur exactly the line worth keeping.
nonisolated protocol PlaceNameResolving: Sendable {
    /// The best available name for a point — a city, or the widest thing that is still true —
    /// or `nil` if there is no network, no answer, or nothing named there.
    func placeName(for coordinates: Coordinates) async -> String?
}

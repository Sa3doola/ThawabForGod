import CoreGraphics
import Foundation
// usage: winid <owner name substring>  → prints the largest on-screen window id of that owner
let owner = CommandLine.arguments[1]
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let best = list.filter { ($0[kCGWindowOwnerName as String] as? String ?? "").contains(owner) && ($0[kCGWindowLayer as String] as? Int) == 0 }
    .max { a, b in
        let ra = a[kCGWindowBounds as String] as? [String: Double] ?? [:], rb = b[kCGWindowBounds as String] as? [String: Double] ?? [:]
        return (ra["Width"] ?? 0) * (ra["Height"] ?? 0) < (rb["Width"] ?? 0) * (rb["Height"] ?? 0)
    }
if let id = best?[kCGWindowNumber as String] as? Int { print(id) } else { exit(1) }

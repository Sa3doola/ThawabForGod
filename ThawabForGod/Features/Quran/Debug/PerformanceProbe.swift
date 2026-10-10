//
//  PerformanceProbe.swift
//  ThawabForGod
//

#if DEBUG
import Darwin
import Foundation
import OSLog

/// Launch time and paging memory for the Mushaf renderer, printed as `PerformanceProbe …` lines
/// that `Tools/QuranBuilder/scripts/measure-performance.sh` collects from a simulator's console.
///
/// Ported from Mushaf, DEBUG only. Simulator numbers are for before/after comparison — this port
/// against Mushaf's last run — not device figures.
@MainActor
enum PerformanceProbe {
    private static var didReportFirstPage = false
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ThawabForGod", category: "Performance")

    /// Time from process start to the first Mushaf page drawn with its text. Reported once.
    static func firstPageAppeared() {
        guard !didReportFirstPage else { return }
        didReportFirstPage = true
        guard let start = processStartDate() else { return }
        report("firstPage=\(Int(Date().timeIntervalSince(start) * 1000))ms footprint=\(footprintMB())MB")
    }

    /// `-quranPageThrough YES`: shows every page in order and reports the peak footprint, plus the
    /// footprint and the registered page fonts every `every` pages — memory must not grow with the
    /// pages visited, and the font window must stay at about seven.
    static func pageThrough(pageCount: Int, every: Int, registeredFonts: () -> Int, show: (Int) -> Void) async {
        try? await Task.sleep(for: .seconds(1))
        var peak = footprintMB()
        let start = Date()
        for page in 1...pageCount {
            show(page)
            try? await Task.sleep(for: .milliseconds(40))
            if Task.isCancelled { return }
            peak = max(peak, footprintMB())
            if page % every == 0 || page == pageCount {
                report("pageThroughAt page=\(page) footprint=\(footprintMB())MB malloc=\(mallocMB())MB registeredPageFonts=\(registeredFonts())")
            }
        }
        report("pageThrough pages=\(pageCount) seconds=\(Int(Date().timeIntervalSince(start))) peakFootprint=\(peak)MB endFootprint=\(footprintMB())MB")
    }

    private static func report(_ message: String) {
        print("PerformanceProbe \(message)")
        logger.info("\(message, privacy: .public)")
    }

    /// The process's physical footprint — what Xcode's memory gauge and jetsam count.
    nonisolated static func footprintMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : -1
    }

    /// Bytes in use in the malloc zones: the heap part of the footprint (the rest is VM such as
    /// rendered glyphs, layers and GPU surfaces).
    nonisolated static func mallocMB() -> Int {
        var stats = malloc_statistics_t()
        malloc_zone_statistics(nil, &stats)
        return Int(stats.size_in_use / 1_048_576)
    }

    private nonisolated static func processStartDate() -> Date? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var process = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        guard sysctl(&mib, UInt32(mib.count), &process, &size, nil, 0) == 0 else { return nil }
        let start = process.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000)
    }
}
#endif

import Foundation

/// A transit stop as returned by the provider (agency-agnostic).
struct Stop: Identifiable, Codable, Hashable {
    let onestopID: String
    let name: String
    let lat: Double
    let lon: Double
    /// The feed this stop belongs to, e.g. `f-princeton~tigertransit` or `f-dr5-nj~transit~bus`.
    let feedOnestopID: String?

    var id: String { onestopID }
}

/// A single upcoming arrival/departure at a stop, normalized across agencies.
struct Arrival: Identifiable, Hashable {
    let id: String
    /// Short route label shown to the user, e.g. "606", "3", "12A".
    let routeShortName: String
    /// Where the bus is headed, e.g. "Merwick to PPPL via Meadows".
    let headsign: String
    /// Scheduled time from the timetable (always present).
    let scheduled: Date
    /// Realtime estimate, present only for feeds that publish GTFS-Realtime.
    let estimated: Date?

    /// True when the feed gave us a live prediction (badge as "live"), false = "sched".
    var isRealtime: Bool { estimated != nil }

    /// The best available time: realtime estimate when present, else scheduled.
    var effective: Date { estimated ?? scheduled }

    /// Whole minutes until the bus arrives, clamped at 0.
    func minutesUntil(from now: Date = Date()) -> Int {
        max(0, Int((effective.timeIntervalSince(now) / 60.0).rounded(.down)))
    }
}

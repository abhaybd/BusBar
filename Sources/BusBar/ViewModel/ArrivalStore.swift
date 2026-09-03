import Foundation
import Combine
import CoreLocation

/// The brain of the app: polls departures for every configured stop, decides which stop is
/// "active" (closest with upcoming buses), applies per-stop route filters, and produces the
/// short string shown in the menu bar.
@MainActor
final class ArrivalStore: ObservableObject {
    @Published private(set) var arrivalsByStop: [String: [Arrival]] = [:]
    /// Route short names seen at each stop (for the per-stop route toggles).
    @Published private(set) var routesByStop: [String: [String]] = [:]
    @Published private(set) var activeStopID: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false
    /// The compact text shown in the menu bar, e.g. "3 · 4m · Forrestal". Published so the
    /// status item can observe it and re-render the button title.
    @Published private(set) var menuText: String = "Set up"

    /// When the user picks a stop from the dropdown, honor it instead of the location-based pick.
    private var manualStopID: String?

    let config: AppConfig
    let location: LocationManager

    private var pollTask: Task<Void, Never>?
    private var displayTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private let pollInterval: TimeInterval = 45
    private let window = 3 * 3600 // fetch 3h of departures

    init(config: AppConfig, location: LocationManager) {
        self.config = config
        self.location = location

        // Re-fetch promptly when the user changes stops, the API key, or their location.
        config.$stops
            .dropFirst()
            .sink { [weak self] _ in self?.refreshSoon() }
            .store(in: &cancellables)
        config.$apiKey
            .dropFirst()
            .sink { [weak self] _ in self?.refreshSoon() }
            .store(in: &cancellables)
        location.$coordinate
            .dropFirst()
            .sink { [weak self] _ in self?.recomputeActiveStop() }
            .store(in: &cancellables)
    }

    func start() {
        location.requestIfNeeded()
        updateMenuText()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
            }
        }
        // Tick the displayed countdown between network polls.
        displayTask?.cancel()
        displayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                self?.updateMenuText()
            }
        }
    }

    private func refreshSoon() {
        Task { await refresh() }
    }

    func refresh() async {
        let key = config.effectiveAPIKey
        let stops = config.stops
        guard !stops.isEmpty else {
            arrivalsByStop = [:]
            routesByStop = [:]
            activeStopID = nil
            lastError = nil
            updateMenuText()
            return
        }
        guard !key.isEmpty else {
            lastError = "No API key. Add one in Settings."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let provider = TransitlandProvider(apiKey: key)
        var newArrivals: [String: [Arrival]] = [:]
        var newRoutes: [String: [String]] = [:]
        var firstError: String?

        await withTaskGroup(of: (String, Result<[Arrival], Error>).self) { group in
            for stop in stops {
                group.addTask {
                    do {
                        let arr = try await provider.departures(
                            stopOnestopID: stop.onestopID, withinSeconds: self.window)
                        return (stop.onestopID, .success(arr))
                    } catch {
                        return (stop.onestopID, .failure(error))
                    }
                }
            }
            for await (stopID, result) in group {
                switch result {
                case .success(let arr):
                    newArrivals[stopID] = arr
                    // Preserve first-seen order of routes.
                    var seen: [String] = []
                    for a in arr where !seen.contains(a.routeShortName) {
                        seen.append(a.routeShortName)
                    }
                    newRoutes[stopID] = seen.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                case .failure(let err):
                    if firstError == nil {
                        firstError = (err as? LocalizedError)?.errorDescription ?? err.localizedDescription
                    }
                }
            }
        }

        arrivalsByStop = newArrivals
        // Merge routes so previously-known routes don't vanish on a quiet fetch.
        for (k, v) in newRoutes where !v.isEmpty { routesByStop[k] = v }
        lastError = firstError
        lastUpdated = Date()
        recomputeActiveStop()
    }

    // MARK: - Derived state

    /// Arrivals for a stop with the user's disabled routes removed.
    func filteredArrivals(for stopID: String) -> [Arrival] {
        let disabled = config.stops.first { $0.onestopID == stopID }?.disabledRoutes ?? []
        let now = Date()
        return (arrivalsByStop[stopID] ?? [])
            .filter { !disabled.contains($0.routeShortName) && $0.effective >= now.addingTimeInterval(-30) }
    }

    /// User explicitly chose a stop in the dropdown; pin it until they pick another.
    func setActiveStop(_ id: String) {
        manualStopID = id
        activeStopID = id
        updateMenuText()
    }

    /// Closest configured stop that has an upcoming (non-disabled) bus; falls back sensibly.
    func recomputeActiveStop() {
        defer { updateMenuText() }
        let stops = config.stops
        guard !stops.isEmpty else { activeStopID = nil; manualStopID = nil; return }

        // Honor a manual pick while it still refers to a configured stop.
        if let manual = manualStopID {
            if stops.contains(where: { $0.onestopID == manual }) {
                activeStopID = manual
                return
            } else {
                manualStopID = nil
            }
        }

        let withBuses = stops.filter { !filteredArrivals(for: $0.onestopID).isEmpty }
        let pool = withBuses.isEmpty ? stops : withBuses

        if let coord = location.coordinate {
            let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            activeStopID = pool.min(by: { a, b in
                here.distance(from: CLLocation(latitude: a.lat, longitude: a.lon)) <
                here.distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
            })?.onestopID
        } else if let current = activeStopID, pool.contains(where: { $0.onestopID == current }) {
            // keep current selection if still valid
        } else {
            activeStopID = pool.first?.onestopID
        }
    }

    var activeStop: ConfiguredStop? {
        guard let id = activeStopID else { return config.stops.first }
        return config.stops.first { $0.onestopID == id } ?? config.stops.first
    }

    /// Recompute and publish `menuText`. Cheap; safe to call from a display timer.
    func updateMenuText() {
        let next = computeMenuText()
        if next != menuText { menuText = next }
    }

    private func computeMenuText() -> String {
        guard !config.stops.isEmpty else { return "Set up" }
        guard let stop = activeStop else { return "—" }
        let arrivals = filteredArrivals(for: stop.onestopID)
        guard let next = arrivals.first else {
            return "\(stop.displayName): none"
        }
        let mins = next.minutesUntil()
        let when = mins <= 0 ? "now" : "\(mins)m"
        return "\(next.routeShortName) · \(when) · \(stop.displayName)"
    }
}

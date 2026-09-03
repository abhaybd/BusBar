import Foundation

/// Talks to the Transitland v2 REST API (https://www.transit.land/documentation/rest-api).
/// One endpoint does the heavy lifting: `/stops/{onestop_id}/departures` merges scheduled
/// timetable data with GTFS-Realtime where the underlying feed provides it.
struct TransitlandProvider: TransitProvider {
    let apiKey: String
    private let base = URL(string: "https://transit.land/api/v2/rest")!
    private let session: URLSession = .shared

    // MARK: - Public API

    func nearbyStops(lat: Double, lon: Double, radiusMeters: Int) async throws -> [Stop] {
        let url = try makeURL(path: "stops", query: [
            "lat": String(lat),
            "lon": String(lon),
            "radius": String(radiusMeters),
            "limit": "40",
        ])
        let resp: StopsResponse = try await get(url)
        return resp.stops.map { $0.toStop() }
    }

    func stop(onestopID: String) async throws -> Stop? {
        let url = try makeURL(path: "stops/\(onestopID)", query: [:])
        let resp: StopsResponse = try await get(url)
        return resp.stops.first?.toStop()
    }

    func departures(stopOnestopID: String, withinSeconds: Int) async throws -> [Arrival] {
        let url = try makeURL(path: "stops/\(stopOnestopID)/departures", query: [
            "next": String(withinSeconds),
        ])
        let resp: DeparturesResponse = try await get(url)
        let now = Date()
        // A stop key can resolve to several physical stops (platforms); flatten them all.
        let arrivals = resp.stops.flatMap { $0.departures ?? [] }.compactMap { $0.toArrival() }
        return arrivals
            .filter { $0.effective >= now.addingTimeInterval(-30) } // drop already-departed
            .sorted { $0.effective < $1.effective }
    }

    // MARK: - HTTP plumbing

    private func makeURL(path: String, query: [String: String]) throws -> URL {
        guard !apiKey.isEmpty else { throw TransitProviderError.missingAPIKey }
        var comps = URLComponents(url: base.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)!
        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "api_key", value: apiKey))
        comps.queryItems = items
        return comps.url!
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("BusBar/0.1 (macOS menu bar)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw TransitProviderError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TransitProviderError.http(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw TransitProviderError.badResponse
        }
    }
}

// MARK: - Wire-format DTOs (private; mapped to clean models above)

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private struct StopsResponse: Decodable {
    let stops: [StopDTO]
}

private struct StopDTO: Decodable {
    let onestop_id: String
    let stop_name: String?
    let geometry: Geometry?
    let feed_version: FeedVersion?

    struct Geometry: Decodable { let coordinates: [Double] } // [lon, lat]
    struct FeedVersion: Decodable {
        let feed: Feed?
        struct Feed: Decodable { let onestop_id: String? }
    }

    func toStop() -> Stop {
        let coords = geometry?.coordinates ?? []
        return Stop(
            onestopID: onestop_id,
            name: stop_name ?? onestop_id,
            lat: coords.count == 2 ? coords[1] : 0,
            lon: coords.count == 2 ? coords[0] : 0,
            feedOnestopID: feed_version?.feed?.onestop_id
        )
    }
}

private struct DeparturesResponse: Decodable {
    let stops: [StopWithDepartures]
    struct StopWithDepartures: Decodable {
        let departures: [DepartureDTO]?
    }
}

private struct DepartureDTO: Decodable {
    let schedule_relationship: String?
    let stop_headsign: String?
    let departure: TimeInfo?
    let arrival: TimeInfo?
    let trip: Trip?

    struct TimeInfo: Decodable {
        let scheduled_utc: String?
        let estimated_utc: String?
    }
    struct Trip: Decodable {
        let trip_id: String?
        let trip_headsign: String?
        let route: Route?
        struct Route: Decodable {
            let route_short_name: String?
            let route_long_name: String?
        }
    }

    func toArrival() -> Arrival? {
        // Skip canceled trips (STATIC/SCHEDULED/ADDED are fine to show).
        if let sr = schedule_relationship?.uppercased(), sr == "CANCELED" || sr == "CANCELLED" {
            return nil
        }
        let time = departure ?? arrival
        guard let schedStr = time?.scheduled_utc,
              let scheduled = isoFormatter.date(from: schedStr) else { return nil }
        let estimated = time?.estimated_utc.flatMap { isoFormatter.date(from: $0) }

        let route = trip?.route?.route_short_name
            ?? trip?.route?.route_long_name
            ?? "?"
        let headsign = stop_headsign
            ?? trip?.trip_headsign
            ?? ""
        // Stable-ish id for SwiftUI diffing: trip + scheduled time.
        let id = "\(trip?.trip_id ?? "?")-\(schedStr)"
        return Arrival(id: id, routeShortName: route, headsign: headsign,
                       scheduled: scheduled, estimated: estimated)
    }
}

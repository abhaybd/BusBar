import Foundation

/// Abstraction over a transit data source. Today only `TransitlandProvider` conforms;
/// a future TripShot/Swiftly adapter for live TigerTransit predictions can conform too,
/// and the rest of the app won't need to change.
protocol TransitProvider {
    /// Stops within `radiusMeters` of a coordinate, nearest first-ish (provider order).
    func nearbyStops(lat: Double, lon: Double, radiusMeters: Int) async throws -> [Stop]

    /// A single stop looked up by its Onestop ID (used when adding by id / refreshing metadata).
    func stop(onestopID: String) async throws -> Stop?

    /// Upcoming arrivals at a stop within the next `withinSeconds`.
    func departures(stopOnestopID: String, withinSeconds: Int) async throws -> [Arrival]
}

enum TransitProviderError: LocalizedError {
    case missingAPIKey
    case http(Int)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No Transitland API key set. Add one in Settings."
        case .http(let code): return "Transitland request failed (HTTP \(code))."
        case .badResponse: return "Unexpected response from Transitland."
        }
    }
}

import Foundation
import Combine

/// A stop the user has chosen to track, plus their per-stop preferences.
struct ConfiguredStop: Codable, Identifiable, Hashable {
    var onestopID: String
    /// Short label shown in the menu bar, e.g. "Frist".
    var displayName: String
    /// Full stop name for the settings/dropdown UI.
    var fullName: String
    var lat: Double
    var lon: Double
    /// Route short names the user has hidden for this stop.
    var disabledRoutes: Set<String> = []

    var id: String { onestopID }
}

/// Persistent user settings, backed by UserDefaults (JSON). Simple and enough for a personal tool.
final class AppConfig: ObservableObject {
    @Published var apiKey: String { didSet { save() } }
    @Published var stops: [ConfiguredStop] { didSet { save() } }

    private static let key = "BusBarConfig.v1"

    private struct Persisted: Codable {
        var apiKey: String
        var stops: [ConfiguredStop]
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            self.apiKey = decoded.apiKey
            self.stops = decoded.stops
        } else {
            self.apiKey = ""
            self.stops = []
        }
    }

    private func save() {
        let persisted = Persisted(apiKey: apiKey, stops: stops)
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    /// GUI-entered key always wins; fall back to the dev `.env` key when unset.
    var effectiveAPIKey: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return Env.transitlandAPIKey ?? ""
    }

    func addStop(_ stop: Stop, displayName: String? = nil) {
        guard !stops.contains(where: { $0.onestopID == stop.onestopID }) else { return }
        stops.append(ConfiguredStop(
            onestopID: stop.onestopID,
            displayName: displayName ?? Self.briefName(from: stop.name),
            fullName: stop.name,
            lat: stop.lat,
            lon: stop.lon
        ))
    }

    func removeStop(_ id: String) {
        stops.removeAll { $0.onestopID == id }
    }

    /// Heuristic short name for the menu bar from a verbose stop name.
    static func briefName(from full: String) -> String {
        // Take the part before a delimiter, cap length.
        let firstChunk = full
            .components(separatedBy: CharacterSet(charactersIn: "(-,"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? full
        let candidate = firstChunk.isEmpty ? full : firstChunk
        return String(candidate.prefix(16))
    }
}

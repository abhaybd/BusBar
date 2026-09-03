import SwiftUI
import CoreLocation

/// The configuration GUI: API key, the list of tracked stops, and a way to add more.
struct SettingsView: View {
    @EnvironmentObject var config: AppConfig
    @EnvironmentObject var store: ArrivalStore
    @EnvironmentObject var location: LocationManager

    @State private var editingStop: ConfiguredStop?

    var body: some View {
        TabView {
            stopsTab.tabItem { Label("Stops", systemImage: "bus") }
            apiKeyTab.tabItem { Label("API Key", systemImage: "key") }
        }
        .frame(width: 460, height: 460)
        .sheet(item: $editingStop) { stop in
            StopEditorView(stop: stop)
                .environmentObject(config)
                .environmentObject(store)
        }
    }

    // MARK: Stops

    private var stopsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracked stops").font(.headline)

            if config.stops.isEmpty {
                Text("No stops yet — add one below.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(config.stops) { stop in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(stop.displayName).fontWeight(.medium)
                                Text(stop.fullName).font(.caption).foregroundStyle(.secondary)
                                if !stop.disabledRoutes.isEmpty {
                                    Text("\(stop.disabledRoutes.count) route(s) hidden")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Routes…") { editingStop = stop }
                            Button(role: .destructive) {
                                config.removeStop(stop.onestopID)
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(minHeight: 120)
            }

            Divider()
            AddStopView()
        }
        .padding(16)
    }

    // MARK: API key

    private var apiKeyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transitland API key").font(.headline)
            Text("Get a free key at transit.land, then paste it here.")
                .font(.caption).foregroundStyle(.secondary)
            SecureField("api_key", text: $config.apiKey)
                .textFieldStyle(.roundedBorder)
            if config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty,
               !(Env.transitlandAPIKey ?? "").isEmpty {
                Label("Using developer key from .env", systemImage: "wrench.and.screwdriver")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}

/// Add-a-stop UI: search near current location, or add directly by Onestop ID.
private struct AddStopView: View {
    @EnvironmentObject var config: AppConfig
    @EnvironmentObject var location: LocationManager

    @State private var results: [Stop] = []
    @State private var status: String?
    @State private var onestopIDInput = ""
    @State private var searching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a stop").font(.subheadline).fontWeight(.semibold)

            HStack {
                Button {
                    Task { await searchNearby() }
                } label: {
                    Label("Find stops near me", systemImage: "location")
                }
                if searching { ProgressView().controlSize(.small) }
            }

            HStack {
                TextField("…or paste an Onestop ID (s-…)", text: $onestopIDInput)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { Task { await addByID() } }
                    .disabled(onestopIDInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let status { Text(status).font(.caption).foregroundStyle(.secondary) }

            if !results.isEmpty {
                List(results) { stop in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(stop.name).lineLimit(1)
                            if let feed = stop.feedOnestopID {
                                Text(feed).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Add") { config.addStop(stop); status = "Added \(stop.name)" }
                            .disabled(config.stops.contains { $0.onestopID == stop.onestopID })
                    }
                }
                .frame(height: 140)
            }
        }
    }

    private var provider: TransitlandProvider { TransitlandProvider(apiKey: config.effectiveAPIKey) }

    private func searchNearby() async {
        guard !config.effectiveAPIKey.isEmpty else { status = "Set an API key first."; return }
        location.requestIfNeeded()
        guard let coord = location.coordinate else {
            status = "Waiting for your location… try again in a moment."
            return
        }
        searching = true; defer { searching = false }
        do {
            results = try await provider.nearbyStops(
                lat: coord.latitude, lon: coord.longitude, radiusMeters: 800)
            status = results.isEmpty ? "No stops within 800m." : "\(results.count) stops nearby."
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func addByID() async {
        let id = onestopIDInput.trimmingCharacters(in: .whitespaces)
        guard !config.effectiveAPIKey.isEmpty else { status = "Set an API key first."; return }
        do {
            if let stop = try await provider.stop(onestopID: id) {
                config.addStop(stop)
                status = "Added \(stop.name)"
                onestopIDInput = ""
            } else {
                status = "No stop found for \(id)."
            }
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

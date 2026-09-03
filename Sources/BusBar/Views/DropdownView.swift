import SwiftUI

/// The panel shown when the user clicks the menu bar item: upcoming arrivals for the active
/// stop, a switcher when several stops are configured, and actions.
struct DropdownView: View {
    @EnvironmentObject var store: ArrivalStore
    @EnvironmentObject var config: AppConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if config.stops.isEmpty {
                empty
            } else {
                if config.stops.count > 1 { stopSwitcher }
                arrivalsList
            }

            Divider()
            footer
        }
        .padding(12)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("BusBar").font(.headline)
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No stops yet.").foregroundStyle(.secondary)
            Text("Open Settings to add a stop.").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var stopSwitcher: some View {
        Picker("Stop", selection: Binding(
            get: { store.activeStop?.onestopID ?? config.stops.first?.onestopID ?? "" },
            set: { store.setActiveStop($0) }
        )) {
            ForEach(config.stops) { s in
                Text(s.displayName).tag(s.onestopID)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }

    private var arrivalsList: some View {
        let stop = store.activeStop
        let arrivals = stop.map { store.filteredArrivals(for: $0.onestopID) } ?? []
        return VStack(alignment: .leading, spacing: 0) {
            if let stop {
                Text(stop.fullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                if arrivals.isEmpty {
                    Text("No upcoming buses").foregroundStyle(.secondary).padding(.vertical, 6)
                } else {
                    ForEach(Array(arrivals.prefix(8))) { a in
                        ArrivalRow(arrival: a)
                    }
                }
            }
            if let err = store.lastError {
                Text(err).font(.caption).foregroundStyle(.red).padding(.top, 6)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let updated = store.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Settings…") { openBusBarSettings() }
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}

private struct ArrivalRow: View {
    let arrival: Arrival

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bus.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(arrival.routeShortName)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(minWidth: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(arrival.headsign.isEmpty ? "—" : arrival.headsign)
                    .font(.caption)
                    .lineLimit(1)
                Text(arrival.isRealtime ? "live" : "sched")
                    .font(.caption2)
                    .foregroundStyle(arrival.isRealtime ? Color.green : Color.secondary)
            }
            Spacer()
            Text(minutesText)
                .font(.system(.body, design: .rounded).weight(.medium))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var minutesText: String {
        let m = arrival.minutesUntil()
        return m <= 0 ? "now" : "\(m) min"
    }
}

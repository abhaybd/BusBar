import SwiftUI

/// Per-stop configuration: rename the menu-bar label and toggle individual routes on/off.
struct StopEditorView: View {
    @EnvironmentObject var config: AppConfig
    @EnvironmentObject var store: ArrivalStore
    @Environment(\.dismiss) private var dismiss

    let stop: ConfiguredStop
    @State private var displayName: String

    init(stop: ConfiguredStop) {
        self.stop = stop
        _displayName = State(initialValue: stop.displayName)
    }

    private var routes: [String] { store.routesByStop[stop.onestopID] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stop.fullName).font(.headline)

            HStack {
                Text("Menu bar name")
                TextField("Short name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveName)
            }

            Divider()
            Text("Show these routes").font(.subheadline).fontWeight(.semibold)

            if routes.isEmpty {
                Text("No routes seen yet. Refresh, then reopen this editor.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                List(routes, id: \.self) { route in
                    Toggle(isOn: bindingForRoute(route)) {
                        Text(route)
                    }
                }
                .frame(minHeight: 160)
            }

            HStack {
                Spacer()
                Button("Done") { saveName(); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 360, height: 400)
    }

    /// A toggle is ON when the route is NOT in the disabled set.
    private func bindingForRoute(_ route: String) -> Binding<Bool> {
        Binding(
            get: { !(currentStop?.disabledRoutes.contains(route) ?? false) },
            set: { isOn in
                guard let idx = config.stops.firstIndex(where: { $0.onestopID == stop.onestopID }) else { return }
                if isOn {
                    config.stops[idx].disabledRoutes.remove(route)
                } else {
                    config.stops[idx].disabledRoutes.insert(route)
                }
            }
        )
    }

    private var currentStop: ConfiguredStop? {
        config.stops.first { $0.onestopID == stop.onestopID }
    }

    private func saveName() {
        guard let idx = config.stops.firstIndex(where: { $0.onestopID == stop.onestopID }) else { return }
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        config.stops[idx].displayName = trimmed.isEmpty ? stop.displayName : trimmed
    }
}

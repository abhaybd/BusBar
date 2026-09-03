import Foundation

/// Headless end-to-end check of the data pipeline (provider + Arrival parsing), run with
/// `BusBar --selftest`. Prints computed arrivals for a couple of known Princeton stops so the
/// whole path can be verified without the menu bar UI. Uses the dev `.env` key.
enum SelfTest {
    static func run() {
        let sema = DispatchSemaphore(value: 0)
        Task {
            await perform()
            sema.signal()
        }
        sema.wait()
        exit(0)
    }

    private static func perform() async {
        let key = Env.transitlandAPIKey ?? ""
        guard !key.isEmpty else {
            print("[selftest] No TRANSITLAND_API_KEY found (env or .env).")
            return
        }
        print("[selftest] key loaded (\(key.prefix(8))…)")
        let provider = TransitlandProvider(apiKey: key)

        let stops = [
            ("TigerTransit — Forrestal (SB)", "s-dr4vw0dtyh-forrestalsb"),
            ("NJ Transit — Nassau & Charlton", "s-dr4vt1wx0h-rt~27nassaustatcharltonst"),
        ]
        for (label, id) in stops {
            print("\n== \(label) ==")
            do {
                let arrivals = try await provider.departures(stopOnestopID: id, withinSeconds: 3 * 3600)
                if arrivals.isEmpty { print("  (no upcoming departures)") }
                for a in arrivals.prefix(6) {
                    let badge = a.isRealtime ? "live " : "sched"
                    print(String(format: "  %-5@ %3dm  %@  %@",
                                 a.routeShortName as NSString,
                                 a.minutesUntil(),
                                 badge,
                                 a.headsign))
                }
            } catch {
                print("  ERROR: \(error)")
            }
        }

        print("\n== nearby search (campus center, 500m) ==")
        do {
            let nearby = try await provider.nearbyStops(lat: 40.3467, lon: -74.6551, radiusMeters: 500)
            print("  \(nearby.count) stops")
            for s in nearby.prefix(6) {
                print("  \(s.onestopID)  —  \(s.name)  [\(s.feedOnestopID ?? "?")]")
            }
        } catch {
            print("  ERROR: \(error)")
        }
    }
}

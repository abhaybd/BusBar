import Foundation

/// Dev-only convenience for loading the Transitland API key without hardcoding a secret.
///
/// Resolution: the process environment first, then a `.env` file discovered by walking up
/// from the current working directory and from the executable's location. End users never
/// rely on this — they enter their own key in Settings. `.env` is git-ignored.
enum Env {
    static var transitlandAPIKey: String? {
        value(for: "TRANSITLAND_API_KEY")
    }

    static func value(for key: String) -> String? {
        if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty {
            return v
        }
        return dotenv[key]
    }

    /// Parsed `.env`, loaded once.
    private static let dotenv: [String: String] = loadDotenv()

    private static func loadDotenv() -> [String: String] {
        guard let url = findDotenv() else { return [:] }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let k = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var v = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if v.count >= 2, (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
                v = String(v.dropFirst().dropLast())
            }
            result[k] = v
        }
        return result
    }

    /// Search cwd and executable dir, walking up a few levels, for a `.env`.
    private static func findDotenv() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        candidates.append(URL(fileURLWithPath: fm.currentDirectoryPath))
        if let exe = Bundle.main.executableURL {
            candidates.append(exe.deletingLastPathComponent())
        }
        for start in candidates {
            var dir = start
            for _ in 0..<6 {
                let candidate = dir.appendingPathComponent(".env")
                if fm.fileExists(atPath: candidate.path) { return candidate }
                let parent = dir.deletingLastPathComponent()
                if parent.path == dir.path { break }
                dir = parent
            }
        }
        return nil
    }
}

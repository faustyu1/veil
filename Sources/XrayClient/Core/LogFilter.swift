import Foundation

/// Narrows the core's log down to the lines someone is actually looking for.
///
/// At debug level a core writes hundreds of lines a minute, so the pane is
/// only useful with a severity floor and a search box. Both have to read two
/// spellings: xray brackets the level (`[Warning]`), sing-box prints it as a
/// bare word (`WARN`), and Veil's own lines carry no level at all.
enum LogFilter {

    /// The lines of `text` that pass both filters, in the order they arrived.
    ///
    /// `minimum` of nil or `.none` keeps every severity.
    static func apply(_ text: String, query: String, minimum: LogLevel?) -> String {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let floor = rank(of: minimum)
        guard !needle.isEmpty || floor != nil else { return text }

        var kept: [Substring] = []
        // A line with no level of its own belongs to the line above it — the
        // second half of "config failed:" is the reason for the error, and
        // hiding it hides why the error happened.
        var inherited: Int?

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let own = level(of: line)
            if own != nil { inherited = own }
            if let floor, let severity = own ?? inherited, severity < floor { continue }
            if !needle.isEmpty,
               line.range(of: needle, options: .caseInsensitive) == nil { continue }
            kept.append(line)
        }
        return kept.joined(separator: "\n")
    }

    // MARK: - Severity

    private static let bracketed: [(String, Int)] = [
        ("[debug]", 0), ("[info]", 1), ("[warning]", 2), ("[warn]", 2),
        ("[error]", 3), ("[fatal]", 4), ("[panic]", 4)
    ]

    private static let bare: [String: Int] = [
        "DEBUG": 0, "TRACE": 0, "INFO": 1, "WARN": 2, "WARNING": 2,
        "ERROR": 3, "FATAL": 4, "PANIC": 4
    ]

    private static func rank(of level: LogLevel?) -> Int? {
        guard let level else { return nil }
        switch level {
        case .debug:   return 0
        case .info:    return 1
        case .warning: return 2
        case .error:   return 3
        case .none:    return nil
        }
    }

    /// The severity this line announces, or nil when it announces none.
    private static func level(of line: Substring) -> Int? {
        let lower = line.lowercased()
        for (token, rank) in bracketed where lower.contains(token) { return rank }
        // sing-box prints the level as a bare uppercase word, so only an
        // all-caps token counts — "Error" inside a sentence is prose.
        for word in line.split(whereSeparator: { !$0.isLetter }) {
            if let rank = bare[String(word)] { return rank }
        }
        return nil
    }
}

//
//  ScheduleShareLogging.swift
//  Friscora
//
//  Unified diagnostics for schedule sharing (invite creation, links, Universal Links, deep links).
//  Use Console.app → select device → filter subsystem `ScheduleShare` or text `[ScheduleShare]`.
//

import Foundation
import os

enum ScheduleShareLogging {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Friscora"
    private static let logger = Logger(subsystem: subsystem, category: "ScheduleShare")

    /// Logs to `os.Logger` (visible in Console.app) and prints in DEBUG builds.
    static func trace(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let text = "[\(file):\(line)] \(message())"
        logger.info("\(text, privacy: .public)")
        #if DEBUG
        print("[ScheduleShare] \(text)")
        #endif
    }

    /// Avoids putting full invite tokens in persistent logs.
    static func redactedTokenDescription(_ token: String, head: Int = 6, tail: Int = 4) -> String {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > head + tail + 2 else { return "(short)" }
        return "\(t.prefix(head))…\(t.suffix(tail))"
    }
}

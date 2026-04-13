//
//  ScheduleDeepLinkRouter.swift
//  Friscora
//
//  Single pipeline: incoming URL → optional invite payload (HTTPS Universal Links + friscora://).
//

import Foundation

enum ScheduleDeepLinkRouter {

    /// Parses HTTPS Universal Links and `friscora://` schedule invite URLs into a payload.
    /// Token may appear in the path (`/schedule/join/<token>`) or in query (`token=`).
    static func invitePayload(from url: URL) -> ShareInvitePayload? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            ScheduleShareLogging.trace("ScheduleDeepLinkRouter: invalid URLComponents")
            return nil
        }

        if components.scheme?.lowercased() == "https" {
            let result = parseHTTPSInvite(components: components)
            if result == nil {
                ScheduleShareLogging.trace(
                    "ScheduleDeepLinkRouter: HTTPS URL not a schedule invite host=\(components.host ?? "?") path=\(components.path)"
                )
            }
            return result
        }
        if components.scheme?.lowercased() == "friscora" {
            let result = parseCustomSchemeInvite(components: components)
            if result == nil {
                ScheduleShareLogging.trace("ScheduleDeepLinkRouter: friscora URL did not yield invite host=\(components.host ?? "?") path=\(components.path)")
            }
            return result
        }
        ScheduleShareLogging.trace("ScheduleDeepLinkRouter: unsupported scheme=\(components.scheme ?? "?")")
        return nil
    }

    // MARK: - HTTPS

    private static func parseHTTPSInvite(components: URLComponents) -> ShareInvitePayload? {
        guard let host = components.host?.lowercased(),
              hostMatchesUniversalLink(host: host) else { return nil }

        let pathParts = components.path
            .split(separator: "/")
            .map(String.init)

        var tokenFromPath: String?
        if pathMatchesInvite(pathParts: pathParts) {
            if let last = pathParts.last, !last.isEmpty {
                tokenFromPath = last
            }
        }

        let queryMap = queryDictionary(from: components)
        let tokenFromQuery = queryMap["token"]?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let token = (tokenFromPath ?? tokenFromQuery)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return nil }

        return buildPayload(token: token, queryMap: queryMap)
    }

    static func hostMatchesUniversalLink(host: String) -> Bool {
        ScheduleSharingConfiguration.matchesScheduleInviteHTTPSHost(host)
    }

    private static func pathMatchesInvite(pathParts: [String]) -> Bool {
        let prefix = ScheduleSharingConfiguration.invitePathComponents
        guard pathParts.count >= prefix.count else { return false }
        for i in prefix.indices {
            if pathParts[i].lowercased() != prefix[i].lowercased() { return false }
        }
        return true
    }

    // MARK: - friscora://

    private static func parseCustomSchemeInvite(components: URLComponents) -> ShareInvitePayload? {
        let host = (components.host ?? "").lowercased()
        let pathParts = components.path
            .split(separator: "/")
            .map(String.init)

        // Legacy: friscora://schedule-share?token=...
        if host == ScheduleSharingConfiguration.customURLSchemeScheduleHostLegacy.lowercased() {
            let queryMap = queryDictionary(from: components)
            guard let token = queryMap["token"]?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
                return nil
            }
            return buildPayload(token: token, queryMap: queryMap)
        }

        // friscora://schedule/join/<token> or friscora://schedule?... or friscora://schedule/join?token=
        if host == ScheduleSharingConfiguration.customURLSchemeScheduleHost.lowercased() {
            let queryMap = queryDictionary(from: components)
            var token = queryMap["token"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if pathMatchesInvite(pathParts: pathParts), let last = pathParts.last, !last.isEmpty {
                token = last
            }
            guard let t = token, !t.isEmpty else { return nil }
            return buildPayload(token: t, queryMap: queryMap)
        }

        return nil
    }

    // MARK: - Shared

    private static func queryDictionary(from components: URLComponents) -> [String: String] {
        var map: [String: String] = [:]
        for item in components.queryItems ?? [] {
            map[item.name] = item.value ?? ""
        }
        return map
    }

    private static func buildPayload(token: String, queryMap: [String: String]) -> ShareInvitePayload {
        let senderRaw = queryMap["sender"] ?? ""
        let sender = senderRaw.removingPercentEncoding ?? senderRaw

        let scope: ShareScope = {
            guard let raw = queryMap["scope"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
                  let s = ShareScope(rawValue: raw) else { return .allMonths }
            return s
        }()

        let shareItems: [ShareItem] = {
            guard let raw = queryMap["items"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return [.shifts, .events]
            }
            let parsed = raw.split(separator: ",").compactMap { ShareItem(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }
            return parsed.isEmpty ? [.shifts, .events] : parsed
        }()

        let expiresAt: Date? = {
            guard let exp = queryMap["exp"]?.trimmingCharacters(in: .whitespacesAndNewlines), !exp.isEmpty else {
                return nil
            }
            return ISO8601DateFormatter().date(from: exp)
        }()

        return ShareInvitePayload(
            token: token,
            senderName: sender,
            scope: scope,
            shareItems: shareItems,
            expiresAt: expiresAt
        )
    }
}

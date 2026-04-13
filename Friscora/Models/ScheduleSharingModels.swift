//
//  ScheduleSharingModels.swift
//  Friscora
//
//  Contracts, API payloads, and UI state for schedule sharing.
//

import Foundation

// MARK: - Sharing surface

enum ShareItem: String, Codable, CaseIterable, Identifiable {
    case shifts
    case events

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shifts: return L10n("schedule.share.item.shifts.title")
        case .events: return L10n("schedule.share.item.events.title")
        }
    }

    var detail: String {
        switch self {
        case .shifts: return L10n("schedule.share.item.shifts.detail")
        case .events: return L10n("schedule.share.item.events.detail")
        }
    }
}

enum ShareScope: String, Codable, CaseIterable, Identifiable {
    case currentMonth
    case allMonths

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .currentMonth:
            return L10n("schedule.share.scope.current_month")
        case .allMonths:
            return L10n("schedule.share.scope.all_months")
        }
    }
}

// MARK: - Outgoing invite (inviter)

struct ShareLinkCreateRequest: Codable, Equatable {
    let ownerDisplayName: String
    let shareItems: [ShareItem]
    let expiresAt: Date?
}

struct ShareLinkCreateResponse: Codable, Equatable {
    let inviteURL: URL
    let token: String
    let expiresAt: Date?
    let shareItems: [ShareItem]
    let joinedCount: Int
}

/// Single unconsumed invite link created by the current user (v2: at most one while not paired).
struct OutgoingScheduleInvite: Identifiable, Codable, Equatable {
    let id: UUID
    let token: String
    let inviteURL: URL
    let ownerDisplayName: String
    let shareItems: [ShareItem]
    let expiresAt: Date?
    let createdAt: Date
}

// MARK: - Deep link / resolve

struct ShareInvitePayload: Codable, Equatable {
    let token: String
    /// Empty until resolved from backend when the link only contains a path token.
    var senderName: String
    var scope: ShareScope
    var shareItems: [ShareItem]
    var expiresAt: Date?
}

/// `GET /schedule/invites/{token}` (conceptual)
struct InviteTokenResolveResponse: Codable, Equatable {
    let senderName: String
    let scope: ShareScope
    let shareItems: [ShareItem]
    let expiresAt: Date?
}

/// `POST /schedule/invites/{token}/accept`
struct AcceptInviteRequest: Codable, Equatable {
    let token: String
    let recipientDisplayName: String
}

struct AcceptInviteResponse: Codable, Equatable {
    let pairingId: UUID
    let partnerDisplayName: String
}

/// `POST /schedule/invites/{token}/decline`
struct DeclineInviteRequest: Codable, Equatable {
    let token: String
}

// MARK: - Pairing

enum SchedulePartnershipRole: String, Codable, Equatable {
    /// Created the invite; partner is the acceptor.
    case inviter
    /// Accepted someone else's invite; partner is the inviter.
    case recipient
}

enum ScheduleSharingServiceError: Error, Equatable {
    case invalidLink
    case expired
    case revoked
    case networkFailure
    /// Already sharing with someone (v2 single-partner rule).
    case alreadyPaired
    /// Revoke the current invite link before creating another.
    case outgoingInviteAlreadyActive
    /// User tried to accept their own invite link.
    case cannotAcceptOwnInvite
    /// Same invite link was already accepted (recipient).
    case inviteAlreadyAccepted
    /// Paired with someone else; must stop before accepting a new invite.
    case alreadyPairedWithDifferentPartner(partnerDisplayName: String)
}

/// Exactly one active partner per user (mutual read-only).
struct SchedulePartnership: Identifiable, Codable, Equatable {
    let id: UUID
    let pairingId: UUID
    let role: SchedulePartnershipRole
    /// The person you are paired with (the one whose calendar you see in partner view).
    let partnerDisplayName: String
    let shareItems: [ShareItem]
    let scope: ShareScope
    let acceptedAt: Date
    /// Invite link token (used to load shared snapshots from Firestore when mock RAM is empty, e.g. after relaunch).
    let inviteToken: String?
}

// MARK: - Partner schedule (API / cache)

/// Server-shaped snapshot for read-only partner calendar (no local job ids; colors as hex).
struct PartnerScheduleSnapshot: Codable, Equatable {
    struct WorkSegment: Codable, Equatable, Identifiable {
        var id: String {
            let s = startMinutesFromMidnight.map(String.init) ?? "x"
            let e = endMinutesFromMidnight.map(String.init) ?? "x"
            return "\(colorHex)-\(hoursWorked)-\(jobName)-\(s)-\(e)"
        }
        let jobName: String
        let hoursWorked: Double
        let colorHex: String
        /// Present when the partner’s shift uses custom times or a named shift; omitted in older snapshots.
        var startMinutesFromMidnight: Int?
        var endMinutesFromMidnight: Int?

        init(
            jobName: String,
            hoursWorked: Double,
            colorHex: String,
            startMinutesFromMidnight: Int? = nil,
            endMinutesFromMidnight: Int? = nil
        ) {
            self.jobName = jobName
            self.hoursWorked = hoursWorked
            self.colorHex = colorHex
            self.startMinutesFromMidnight = startMinutesFromMidnight
            self.endMinutesFromMidnight = endMinutesFromMidnight
        }

        /// Localized time range for a calendar day (same convention as `PersonalEventSummary`).
        func shiftTimeRangeLine(dayStart: Date, calendar: Calendar, locale: Locale) -> String? {
            guard let s = startMinutesFromMidnight, let e = endMinutesFromMidnight else { return nil }
            guard let start = calendar.date(byAdding: .minute, value: s, to: dayStart),
                  var end = calendar.date(byAdding: .minute, value: e, to: dayStart) else {
                return nil
            }
            if end <= start {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "hma", options: 0, locale: locale) ?? "h:mm a"
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        }

        /// Shorter range for tiny calendar cells (locale-aware short time).
        func compactShiftTimeRangeLine(dayStart: Date, calendar: Calendar, locale: Locale) -> String? {
            guard let s = startMinutesFromMidnight, let e = endMinutesFromMidnight else { return nil }
            guard let start = calendar.date(byAdding: .minute, value: s, to: dayStart),
                  var end = calendar.date(byAdding: .minute, value: e, to: dayStart) else {
                return nil
            }
            if end <= start {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let fmt = DateFormatter()
            fmt.locale = locale
            fmt.timeStyle = .short
            fmt.dateStyle = .none
            return "\(fmt.string(from: start))–\(fmt.string(from: end))"
        }
    }

    /// Minimal personal-event payload for shared snapshots (no local UUID).
    struct PersonalEventSummary: Codable, Equatable, Identifiable {
        var id: String { "\(startMinutesFromMidnight)-\(endMinutesFromMidnight)-\(title)" }
        let title: String
        let startMinutesFromMidnight: Int
        let endMinutesFromMidnight: Int
        var showAsBusy: Bool?

        func displayTitle(busyFallback: String) -> String {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if showAsBusy == true && trimmed.isEmpty { return busyFallback }
            return trimmed.isEmpty ? busyFallback : trimmed
        }

        /// Localized time range for a concrete calendar day (minutes are interpreted on `dayStart`).
        func timeRangeLine(dayStart: Date, calendar: Calendar, locale: Locale) -> String {
            guard let start = calendar.date(byAdding: .minute, value: startMinutesFromMidnight, to: dayStart),
                  var end = calendar.date(byAdding: .minute, value: endMinutesFromMidnight, to: dayStart) else {
                return ""
            }
            if end <= start {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "hma", options: 0, locale: locale) ?? "h:mm a"
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        }
    }

    struct DayBucket: Codable, Equatable {
        var work: [WorkSegment]
        /// Legacy count when `personalEvents` was not serialized; kept for backward-compatible decoding.
        var personalEventCount: Int
        /// Populated for new exports when events are shared; older snapshots decode as `[]`.
        var personalEvents: [PersonalEventSummary]

        init(work: [WorkSegment], personalEventCount: Int, personalEvents: [PersonalEventSummary] = []) {
            self.work = work
            self.personalEventCount = personalEventCount
            self.personalEvents = personalEvents
        }

        /// Prefer detailed rows; fall back to legacy count-only buckets.
        var displayablePersonalEventCount: Int {
            if !personalEvents.isEmpty { return personalEvents.count }
            return personalEventCount
        }

        enum CodingKeys: String, CodingKey {
            case work
            case personalEventCount
            case personalEvents
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            work = try c.decodeIfPresent([WorkSegment].self, forKey: .work) ?? []
            personalEventCount = try c.decodeIfPresent(Int.self, forKey: .personalEventCount) ?? 0
            personalEvents = try c.decodeIfPresent([PersonalEventSummary].self, forKey: .personalEvents) ?? []
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(work, forKey: .work)
            try c.encode(personalEventCount, forKey: .personalEventCount)
            try c.encode(personalEvents, forKey: .personalEvents)
        }
    }

    /// Keys: `yyyy-MM-dd` in `Calendar.current` (same as exporter).
    let days: [String: DayBucket]
    let shareItems: [ShareItem]
}

enum ShareContextSource: Equatable {
    case mySchedule
    case partner
}

enum ShareLinkErrorState: Equatable {
    case invalidLink
    case expired
    case revoked
    case declined
    case networkFailure
    case alreadyPaired
    case inviteDisabledWhilePaired
    /// Revoke the active link before generating a new one.
    case activeOutgoingInviteExists
    /// Partner stopped sharing or deleted the pairing document.
    case peerEndedSharing(partnerName: String)
    /// Opened own invite link (inviter).
    case cannotAcceptOwnInvite
    /// Opened an invite link that was already accepted on this device.
    case inviteAlreadyAccepted
    /// Must stop current pairing before accepting another invite (`%@` = current partner name).
    case mustStopToSwitchPartner(partnerName: String)
}

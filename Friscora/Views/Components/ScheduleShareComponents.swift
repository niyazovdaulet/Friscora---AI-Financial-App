//
//  ScheduleShareComponents.swift
//  Friscora
//
//  Reusable views for schedule share flow.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Sheet content height (tighter detents than `.medium`)

private struct ScheduleShareSheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    /// Measures laid-out height so `.presentationDetents([.height(...)])` can hug short forms without a tall dead zone.
    func scheduleShareMeasuredSheetHeight(_ height: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: ScheduleShareSheetContentHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ScheduleShareSheetContentHeightKey.self) { h in
            if h > 0 {
                height.wrappedValue = min(h + 28, 900)
            }
        }
    }
}

// MARK: - Partner day detail (read-only)

struct PartnerScheduleDayDetailView: View {
    let date: Date
    let bucket: PartnerScheduleSnapshot.DayBucket
    let shareItems: [ShareItem]

    private var calendar: Calendar { ScheduleSharingScheduleExporter.gridCalendar }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(formattedFullDate)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppColorTheme.textPrimary)

                if shareItems.contains(.shifts) {
                    sectionHeader(L10n("schedule.share.partner.detail.shifts_section"))
                    if bucket.work.isEmpty {
                        Text(L10n("schedule.share.partner.detail.no_shifts"))
                            .font(.subheadline)
                            .foregroundColor(AppColorTheme.textSecondary)
                    } else {
                        ForEach(bucket.work) { seg in
                            partnerShiftRow(segment: seg)
                        }
                    }
                }

                if shareItems.contains(.events) {
                    sectionHeader(L10n("schedule.share.partner.detail.events_section"))
                    if !bucket.personalEvents.isEmpty {
                        ForEach(Array(bucket.personalEvents.enumerated()), id: \.offset) { _, ev in
                            partnerEventRow(summary: ev)
                        }
                    } else if bucket.personalEventCount > 0 {
                        Text(String(format: L10n("schedule.share.partner.detail.legacy_event_count"), bucket.personalEventCount))
                            .font(.subheadline)
                            .foregroundColor(AppColorTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n("schedule.share.partner.detail.legacy_event_note"))
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L10n("schedule.share.partner.detail.no_events"))
                            .font(.subheadline)
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(AppColorTheme.background.ignoresSafeArea())
    }

    private var formattedFullDate: String {
        let df = DateFormatter()
        df.locale = LocalizationManager.shared.currentLocale
        df.dateStyle = .full
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(AppColorTheme.textTertiary)
            .textCase(.uppercase)
    }

    private func partnerShiftRow(segment: PartnerScheduleSnapshot.WorkSegment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(partnerScheduleSegmentColor(hex: segment.colorHex).opacity(0.45))
                .frame(width: 6, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(partnerScheduleSegmentColor(hex: segment.colorHex).opacity(0.9), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.jobName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                if let timeLine = segment.shiftTimeRangeLine(
                    dayStart: calendar.startOfDay(for: date),
                    calendar: calendar,
                    locale: LocalizationManager.shared.currentLocale
                ) {
                    Text(timeLine)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColorTheme.textSecondary)
                }
                Text(formatHours(segment.hoursWorked))
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppColorTheme.elevatedBackground.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func partnerEventRow(summary: PartnerScheduleSnapshot.PersonalEventSummary) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let title = summary.displayTitle(busyFallback: L10n("schedule.share.partner.event.busy"))
        let timeLine = summary.timeRangeLine(
            dayStart: dayStart,
            calendar: calendar,
            locale: LocalizationManager.shared.currentLocale
        )
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .foregroundColor(AppColorTheme.sapphire)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                if !timeLine.isEmpty {
                    Text(timeLine)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColorTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppColorTheme.elevatedBackground.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatHours(_ hours: Double) -> String {
        if hours == floor(hours) {
            return String(format: "%.0f %@", hours, L10n("work.hours_short"))
        }
        return String(format: "%.1f %@", hours, L10n("work.hours_short"))
    }

    private func partnerScheduleSegmentColor(hex: String) -> Color {
        let t = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 6 else { return AppColorTheme.accent }
        return Color(hex: t)
    }
}

struct ShareIntroView: View {
    let isCreateEnabled: Bool
    let onCreateInvite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n("schedule.share.intro.title"))
                .font(.title2.weight(.bold))
                .foregroundColor(AppColorTheme.textPrimary)
            Text(L10n("schedule.share.intro.body"))
                .font(.subheadline)
                .foregroundColor(AppColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onCreateInvite) {
                Text(L10n("schedule.share.intro.create"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColorTheme.accent.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!isCreateEnabled)
            .opacity(isCreateEnabled ? 1 : 0.45)
        }
        .padding()
        .background(AppColorTheme.cardBackground.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ShareOptionsSheet: View {
    @Binding var selectedItems: Set<ShareItem>
    let isContinueEnabled: Bool
    let isLoading: Bool
    let duplicateSelectionWarning: String?
    let onContinue: () -> Void
    @State private var measuredContentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(AppColorTheme.textTertiary.opacity(0.35))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)

            Text(L10n("schedule.share.options.title"))
                .font(.title3.weight(.bold))
                .foregroundColor(AppColorTheme.textPrimary)

            Text(L10n("schedule.share.options.subtitle"))
                .font(.subheadline)
                .foregroundColor(AppColorTheme.textSecondary)

            ForEach(ShareItem.allCases) { item in
                shareOptionRow(for: item)
            }

            if let duplicateSelectionWarning {
                Text(duplicateSelectionWarning)
                    .font(.caption)
                    .foregroundColor(AppColorTheme.warning)
            }

            Button(isLoading ? L10n("schedule.share.options.creating") : L10n("schedule.share.options.continue"), action: onContinue)
                .disabled(!isContinueEnabled || isLoading)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: isContinueEnabled
                            ? [AppColorTheme.accent.opacity(0.65), AppColorTheme.accent.opacity(0.38)]
                            : [AppColorTheme.elevatedBackground.opacity(0.9), AppColorTheme.elevatedBackground.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(AppColorTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppColorTheme.textPrimary.opacity(0.08), lineWidth: 1)
                )
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .scheduleShareMeasuredSheetHeight($measuredContentHeight)
        .presentationDetents([.height(max(measuredContentHeight > 0 ? measuredContentHeight : 360, 260))])
        .presentationDragIndicator(.visible)
        .background(AppColorTheme.background.ignoresSafeArea())
    }

    private func shareOptionRow(for item: ShareItem) -> some View {
        let selected = selectedItems.contains(item)
        return Button {
            if selected { selectedItems.remove(item) } else { selectedItems.insert(item) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item == .shifts ? "briefcase.fill" : "calendar")
                    .foregroundColor(selected ? AppColorTheme.accent : AppColorTheme.textSecondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .foregroundColor(AppColorTheme.textPrimary)
                        .font(.headline)
                    Text(item.detail)
                        .foregroundColor(AppColorTheme.textSecondary)
                        .font(.caption)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? AppColorTheme.accent : AppColorTheme.textTertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                LinearGradient(
                    colors: selected
                        ? [AppColorTheme.accent.opacity(0.18), AppColorTheme.elevatedBackground]
                        : [AppColorTheme.elevatedBackground, AppColorTheme.elevatedBackground.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ActiveInviteCard: View {
    let invite: OutgoingScheduleInvite
    let copied: Bool
    let onCopy: () -> Void
    let onStop: () -> Void
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n("schedule.share.card.https_label"))
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColorTheme.textSecondary)
            Text(invite.inviteURL.absoluteString)
                .font(.caption)
                .foregroundColor(AppColorTheme.textSecondary)
                .lineLimit(2)
            HStack {
                Spacer(minLength: 0)
                Button(copied ? L10n("schedule.share.card.copied") : L10n("schedule.share.card.copy"), action: onCopy)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColorTheme.accent)
            }
            if let expires = invite.expiresAt {
                Text(String(format: L10n("schedule.share.card.expires_in"), countdownText(until: expires, now: now)))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            } else {
                Text(L10n("schedule.share.card.expires_never"))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            }
            Text(String(format: L10n("schedule.share.card.shared_items"), invite.shareItems.map(\.title).joined(separator: ", ")))
                .font(.caption)
                .foregroundColor(AppColorTheme.textSecondary)

            Button(L10n("schedule.share.card.stop_link"), role: .destructive, action: onStop)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColorTheme.negative.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding()
        .background(AppColorTheme.cardBackground.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onReceive(timer) { now = $0 }
    }

    private func countdownText(until expiry: Date, now: Date) -> String {
        let remaining = Int(expiry.timeIntervalSince(now))
        if remaining <= 0 { return L10n("schedule.share.card.expired_short") }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct InviteAcceptanceSheet: View {
    let invite: ShareInvitePayload
    @Binding var recipientName: String
    let isLoading: Bool
    let errorText: String?
    let onAccept: () -> Void
    let onDecline: () -> Void

    @FocusState private var nameFieldFocused: Bool

    private var trimmedNameOK: Bool {
        !recipientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canAccept: Bool {
        trimmedNameOK && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Capsule()
                    .fill(AppColorTheme.textTertiary.opacity(0.35))
                    .frame(width: 44, height: 5)
                    .frame(maxWidth: .infinity)

                Text(L10n("schedule.share.invite.title"))
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppColorTheme.textPrimary)

                Text(String(format: L10n("schedule.share.invite.lead"), invite.senderName))
                    .font(.subheadline)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(itemsSummary)
                    .font(.subheadline)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n("schedule.share.invite.readonly_bullets"))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n("schedule.share.invite.recipient_label"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColorTheme.textSecondary)

                TextField(L10n("schedule.share.invite.recipient_placeholder"), text: $recipientName)
                    .focused($nameFieldFocused)
                    .padding(12)
                    .background(AppColorTheme.elevatedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(L10n("schedule.share.invite.mutual_footer"))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(AppColorTheme.negative)
                }

                HStack(spacing: 12) {
                    Button(L10n("schedule.share.invite.decline"), role: .destructive, action: onDecline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColorTheme.negative.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button(isLoading ? L10n("schedule.share.invite.accepting") : L10n("schedule.share.invite.accept"), action: onAccept)
                        .disabled(!canAccept)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: canAccept
                                    ? [AppColorTheme.accent.opacity(0.62), AppColorTheme.accent.opacity(0.36)]
                                    : [AppColorTheme.elevatedBackground.opacity(0.95), AppColorTheme.elevatedBackground.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(canAccept ? AppColorTheme.textPrimary : AppColorTheme.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    AppColorTheme.textPrimary.opacity(canAccept ? 0.08 : 0.04),
                                    lineWidth: 1
                                )
                        )
                        .opacity(canAccept ? 1 : 0.55)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture {
            guard nameFieldFocused else { return }
            nameFieldFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .presentationDetents([.fraction(0.48), .large])
        .presentationDragIndicator(.visible)
        .background(AppColorTheme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n("common.done")) {
                    nameFieldFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .foregroundColor(AppColorTheme.accent)
            }
        }
    }

    private var itemsSummary: String {
        let names = invite.shareItems.map(\.title).joined(separator: ", ")
        return String(format: L10n("schedule.share.invite.items_included"), names)
    }
}

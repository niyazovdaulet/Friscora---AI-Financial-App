//
//  ScheduleSharingViewModel.swift
//  Friscora
//
//  State and intent handlers for schedule sharing (v2: single partner, HTTPS links).
//

import Foundation
import Combine

@MainActor
final class ScheduleSharingViewModel: ObservableObject {
    private var repositoryObservation: AnyCancellable?
    @Published var activeSource: ShareContextSource = .mySchedule
    @Published var pendingInvite: ShareInvitePayload?
    @Published var recipientNameInput: String = ""
    @Published var consentErrorMessage: String?
    @Published var linkErrorState: ShareLinkErrorState?
    @Published var isPerformingNetworkAction: Bool = false
    @Published var isShowingShareScreen: Bool = false
    @Published var isShowingShareOptionsSheet: Bool = false
    @Published var nameInput: String = ""
    @Published var selectedShareItems: Set<ShareItem> = []
    @Published var inviteCreationErrorMessage: String?
    @Published var copyFeedbackToken: String?
    @Published var partnerMonthSnapshot: PartnerScheduleSnapshot?

    private let repository: ScheduleSharingRepository
    /// Month last used for `ensurePartnerSnapshot` — reapplied when Firestore pushes a partner update.
    private var lastPartnerSnapshotMonth: Date = Date()
    /// Month currently shown by `WorkScheduleView`’s pager — listener uses this so partner data refreshes before the first async `ensurePartnerSnapshot` finishes.
    private var schedulePagerVisibleMonth: Date = Date()
    private var workSchedulePushCancellable: AnyCancellable?

    @MainActor
    init(repository: ScheduleSharingRepository) {
        self.repository = repository
        repositoryObservation = repository.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    /// Default wiring for the Schedule tab (`StateObject` entry point).
    @MainActor
    convenience init() {
        self.init(repository: ScheduleSharingRepository.shared)
    }

    var partnership: SchedulePartnership? { repository.partnership }
    var outgoingInvite: OutgoingScheduleInvite? { repository.outgoingInvite }

    var isReadOnlySharedContext: Bool {
        activeSource == .partner
    }

    /// Month subtitle under the calendar header. `nil` hides the pill when you are not sharing and have no active invite.
    var scheduleCalendarContextSubtitle: String? {
        switch activeSource {
        case .partner:
            guard partnership != nil else { return nil }
            let name = partnership?.partnerDisplayName ?? L10n("schedule.share.partner.fallback_name")
            return String(format: L10n("schedule.share.pill.partner_possessive"), name)
        case .mySchedule:
            guard partnership != nil || outgoingInvite != nil else { return nil }
            return L10n("schedule.share.pill.my_schedule")
        }
    }

    var canContinueShareOptions: Bool {
        !selectedShareItems.isEmpty
    }

    var canCreateInvite: Bool {
        validateRecipientName(nameInput)
            && !selectedShareItems.isEmpty
            && partnership == nil
            && outgoingInvite == nil
    }

    var hasDuplicateActiveInviteForSelection: Bool {
        guard let out = outgoingInvite, !selectedShareItems.isEmpty else { return false }
        return Set(out.shareItems) == selectedShareItems
    }

    func togglePartnerScheduleView() {
        guard partnership != nil else { return }
        if activeSource == .partner {
            activeSource = .mySchedule
        } else {
            activeSource = .partner
        }
    }

    func validateRecipientName(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func resetInviteDraft() {
        nameInput = ""
        selectedShareItems = []
        inviteCreationErrorMessage = nil
    }

    func toggleShareItem(_ item: ShareItem) {
        if selectedShareItems.contains(item) {
            selectedShareItems.remove(item)
        } else {
            selectedShareItems.insert(item)
        }
    }

    func onScheduleTabAppear() async {
        ScheduleShareLogging.trace("ViewModel.onScheduleTabAppear")
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }
        do {
            try await repository.refreshPairingStatus()
            startOutgoingInvitePairingObserverIfNeeded()
            reconcileLiveFirestoreSyncObservers()
            if let partnerName = repository.consumePeerEndedSharingNotice() {
                linkErrorState = .peerEndedSharing(partnerName: partnerName)
                activeSource = .mySchedule
                partnerMonthSnapshot = nil
            }
            if partnership != nil, activeSource == .partner {
                // Snapshot month filled by ensurePartnerSnapshot from the view.
            }
        } catch {
            ScheduleShareLogging.trace("ViewModel.onScheduleTabAppear refreshPairingStatus failed: \(String(describing: error))")
            linkErrorState = .networkFailure
        }
    }

    /// Validates before showing the accept-invite sheet (deep link / Messages). On failure sets `linkErrorState` for the alert.
    func validateIncomingInvite(_ invite: ShareInvitePayload) -> Bool {
        if let out = outgoingInvite?.token, out == invite.token {
            linkErrorState = .cannotAcceptOwnInvite
            return false
        }
        if let p = partnership {
            if let pTok = p.inviteToken, pTok == invite.token {
                if p.role == .inviter {
                    linkErrorState = .cannotAcceptOwnInvite
                    return false
                }
                linkErrorState = .inviteAlreadyAccepted
                return false
            }
            linkErrorState = .mustStopToSwitchPartner(partnerName: p.partnerDisplayName)
            return false
        }
        linkErrorState = nil
        return true
    }

    private func handleRemotePairingDocumentRemoved() {
        repository.applyRemotePairingDocumentRemoved()
        workSchedulePushCancellable?.cancel()
        workSchedulePushCancellable = nil
        SchedulePairingFirestoreSync.stopListeningForPairedDocumentSnapshotUpdates()
        activeSource = .mySchedule
        partnerMonthSnapshot = nil
        if let partnerName = repository.consumePeerEndedSharingNotice() {
            linkErrorState = .peerEndedSharing(partnerName: partnerName)
        }
    }

    /// Starts (or restarts) Firestore listener for partner snapshot updates + debounced upload of local schedule when paired.
    func reconcileLiveFirestoreSyncObservers() {
        workSchedulePushCancellable?.cancel()
        workSchedulePushCancellable = nil
        SchedulePairingFirestoreSync.stopListeningForPairedDocumentSnapshotUpdates()

        guard let p = partnership, let token = p.inviteToken else { return }

        SchedulePairingFirestoreSync.startListeningForPairedDocumentSnapshotUpdates(
            token: token,
            pairingId: p.pairingId,
            onUpdate: { [weak self] in
                Task { @MainActor in
                    guard let self, self.activeSource == .partner, self.partnership != nil else { return }
                    await self.ensurePartnerSnapshot(for: self.schedulePagerVisibleMonth)
                }
            },
            onDocumentRemoved: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.handleRemotePairingDocumentRemoved()
                }
            }
        )

        let work = WorkScheduleService.shared
        workSchedulePushCancellable = Publishers.Merge(
            work.$workDays.map { _ in () }.eraseToAnyPublisher(),
            work.$personalEvents.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .seconds(1.25), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            Task { await self?.pushLocalScheduleSnapshotToFirestoreIfNeeded() }
        }
    }

    private func pushLocalScheduleSnapshotToFirestoreIfNeeded() async {
        guard let p = partnership, let token = p.inviteToken else { return }
        let snap = ScheduleSharingScheduleExporter.exportSnapshot(shareItems: Set(p.shareItems))
        do {
            try await SchedulePairingFirestoreSync.publishUpdatedScheduleSnapshot(token: token, role: p.role, snapshot: snap)
        } catch {
            ScheduleShareLogging.trace("ViewModel.pushLocalSnapshot failed: \(String(describing: error))")
        }
    }

    /// Inviter: listens to Firestore until the recipient’s accept merges into `schedulePairings/{token}` so the partner toggle appears without switching tabs.
    func startOutgoingInvitePairingObserverIfNeeded() {
        guard partnership == nil, let token = outgoingInvite?.token else {
            SchedulePairingFirestoreSync.stopListeningForRecipientAcceptance()
            return
        }
        SchedulePairingFirestoreSync.startListeningForRecipientAcceptance(token: token) {
            Task { @MainActor in
                self.isPerformingNetworkAction = true
                defer { self.isPerformingNetworkAction = false }
                try? await self.repository.refreshPairingStatus()
                if self.partnership != nil {
                    SchedulePairingFirestoreSync.stopListeningForRecipientAcceptance()
                    self.reconcileLiveFirestoreSyncObservers()
                }
            }
        }
    }

    /// Call whenever the schedule month pager moves so Firestore live updates target the visible month.
    func syncSchedulePagerVisibleMonth(_ month: Date) {
        schedulePagerVisibleMonth = month
    }

    func ensurePartnerSnapshot(for month: Date) async {
        guard activeSource == .partner, partnership != nil else {
            partnerMonthSnapshot = nil
            return
        }
        lastPartnerSnapshotMonth = month
        schedulePagerVisibleMonth = month
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }
        do {
            let snap = try await repository.partnerSnapshot(for: month)
            partnerMonthSnapshot = snap
            let keys = snap.days.keys.sorted().joined(separator: ",")
            ScheduleShareLogging.trace(
                "ViewModel.ensurePartnerSnapshot month=\(ScheduleSharingScheduleExporter.dayKey(for: month)) dayKeys=\(snap.days.count) keys=[\(keys)]"
            )
        } catch {
            linkErrorState = .networkFailure
            partnerMonthSnapshot = nil
        }
    }

    func partnerDayBucket(for date: Date) -> PartnerScheduleSnapshot.DayBucket? {
        guard let snap = partnerMonthSnapshot else { return nil }
        let key = ScheduleSharingScheduleExporter.dayKey(for: date)
        if let bucket = snap.days[key] { return bucket }
        // Keys come from the partner device’s export; rare time-of-day mismatches can miss the string match.
        let cal = ScheduleSharingScheduleExporter.gridCalendar
        for (storedKey, bucket) in snap.days {
            guard let keyDate = ScheduleSharingScheduleExporter.dayKeyToDate(storedKey) else { continue }
            if cal.isDate(keyDate, inSameDayAs: date) { return bucket }
        }
        return nil
    }

    func createInviteFromDraft(expiresAt: Date?) async {
        ScheduleShareLogging.trace("ViewModel.createInviteFromDraft exp=\(expiresAt.map { "\($0)" } ?? "nil") items=\(selectedShareItems.map(\.rawValue))")
        guard validateRecipientName(nameInput) else {
            ScheduleShareLogging.trace("ViewModel.createInviteFromDraft aborted: name invalid")
            inviteCreationErrorMessage = L10n("schedule.share.error.name_required")
            return
        }
        guard !selectedShareItems.isEmpty else {
            ScheduleShareLogging.trace("ViewModel.createInviteFromDraft aborted: no items")
            inviteCreationErrorMessage = L10n("schedule.share.error.items_required")
            return
        }
        if hasDuplicateActiveInviteForSelection {
            ScheduleShareLogging.trace("ViewModel.createInviteFromDraft aborted: duplicate selection")
            inviteCreationErrorMessage = L10n("schedule.share.error.duplicate_selection")
            return
        }

        inviteCreationErrorMessage = nil
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }

        do {
            let req = ShareLinkCreateRequest(
                ownerDisplayName: nameInput.trimmingCharacters(in: .whitespacesAndNewlines),
                shareItems: Array(selectedShareItems),
                expiresAt: expiresAt
            )
            _ = try await repository.createInvite(from: req)
            ScheduleShareLogging.trace("ViewModel.createInviteFromDraft success")
            isShowingShareOptionsSheet = false
            startOutgoingInvitePairingObserverIfNeeded()
        } catch let e as ScheduleSharingServiceError {
            ScheduleShareLogging.trace("ViewModel.createInviteFromDraft serviceError: \(String(describing: e))")
            inviteCreationErrorMessage = messageForCreateError(e)
            linkErrorState = mapServiceError(e)
        } catch {
            ScheduleShareLogging.trace("ViewModel.createInviteFromDraft error: \(String(describing: error))")
            inviteCreationErrorMessage = L10n("schedule.share.error.create_failed")
            linkErrorState = .networkFailure
        }
    }

    func revokeOutgoingInvite() async {
        SchedulePairingFirestoreSync.stopListeningForRecipientAcceptance()
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }
        do {
            try await repository.revokeOutgoingInvite()
        } catch {
            linkErrorState = .networkFailure
        }
    }

    func inviteCardDisplayModel(from response: ShareLinkCreateResponse, ownerName: String) -> OutgoingScheduleInvite {
        OutgoingScheduleInvite(
            id: UUID(),
            token: response.token,
            inviteURL: response.inviteURL,
            ownerDisplayName: ownerName,
            shareItems: response.shareItems,
            expiresAt: response.expiresAt,
            createdAt: Date()
        )
    }

    func markCopied(token: String) {
        ScheduleShareLogging.trace("ViewModel.markCopied token=\(ScheduleShareLogging.redactedTokenDescription(token))")
        copyFeedbackToken = token
    }

    func purgeExpiredInvites() {
        guard let exp = outgoingInvite?.expiresAt, exp <= Date() else { return }
        Task { await revokeOutgoingInvite() }
    }

    func consumeIncomingInvite(_ invite: ShareInvitePayload) {
        ScheduleShareLogging.trace(
            "ViewModel.consumeIncomingInvite token=\(ScheduleShareLogging.redactedTokenDescription(invite.token)) sender=\(invite.senderName)"
        )
        pendingInvite = invite
        recipientNameInput = ""
        consentErrorMessage = nil
        linkErrorState = nil
    }

    /// When the payload has no sender (path-only HTTPS), resolve from API.
    func resolvePendingInviteIfNeeded() async {
        guard let invite = pendingInvite else { return }
        if !invite.senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScheduleShareLogging.trace("ViewModel.resolvePendingInviteIfNeeded: sender already present, skip API")
            return
        }
        ScheduleShareLogging.trace("ViewModel.resolvePendingInviteIfNeeded: resolving token=\(ScheduleShareLogging.redactedTokenDescription(invite.token))")
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }
        do {
            let resolved = try await repository.resolveInviteToken(invite.token)
            ScheduleShareLogging.trace("ViewModel.resolvePendingInviteIfNeeded: resolved sender=\(resolved.senderName)")
            pendingInvite = ShareInvitePayload(
                token: invite.token,
                senderName: resolved.senderName,
                scope: resolved.scope,
                shareItems: resolved.shareItems,
                expiresAt: resolved.expiresAt
            )
        } catch let e as ScheduleSharingServiceError {
            ScheduleShareLogging.trace("ViewModel.resolvePendingInviteIfNeeded serviceError: \(String(describing: e))")
            linkErrorState = mapError(e)
        } catch {
            ScheduleShareLogging.trace("ViewModel.resolvePendingInviteIfNeeded error: \(String(describing: error))")
            linkErrorState = .networkFailure
        }
    }

    func declineInvite() async {
        ScheduleShareLogging.trace("ViewModel.declineInvite")
        if let token = pendingInvite?.token {
            try? await repository.declineInvite(token: token)
        }
        linkErrorState = .declined
        pendingInvite = nil
        recipientNameInput = ""
    }

    func approveInvite() async {
        guard let invite = pendingInvite else {
            ScheduleShareLogging.trace("ViewModel.approveInvite: no pending invite")
            return
        }
        guard validateRecipientName(recipientNameInput) else {
            consentErrorMessage = L10n("schedule.share.error.recipient_name_required")
            return
        }
        consentErrorMessage = nil
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }

        do {
            ScheduleShareLogging.trace("ViewModel.approveInvite: accepting…")
            try await repository.acceptInvite(
                token: invite.token,
                recipientDisplayName: recipientNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            ScheduleShareLogging.trace("ViewModel.approveInvite: success, switching to partner view")
            activeSource = .partner
            pendingInvite = nil
            recipientNameInput = ""
            reconcileLiveFirestoreSyncObservers()
        } catch let e as ScheduleSharingServiceError {
            ScheduleShareLogging.trace("ViewModel.approveInvite serviceError: \(String(describing: e))")
            linkErrorState = mapError(e)
        } catch {
            ScheduleShareLogging.trace("ViewModel.approveInvite error: \(String(describing: error))")
            linkErrorState = .networkFailure
        }
    }

    func stopSharing() async {
        workSchedulePushCancellable?.cancel()
        workSchedulePushCancellable = nil
        SchedulePairingFirestoreSync.stopListeningForPairedDocumentSnapshotUpdates()
        isPerformingNetworkAction = true
        defer { isPerformingNetworkAction = false }
        do {
            try await repository.stopSharing()
            activeSource = .mySchedule
            partnerMonthSnapshot = nil
        } catch {
            linkErrorState = .networkFailure
        }
    }

    private func mapError(_ error: ScheduleSharingServiceError) -> ShareLinkErrorState {
        switch error {
        case .invalidLink: return .invalidLink
        case .expired: return .expired
        case .revoked: return .revoked
        case .networkFailure: return .networkFailure
        case .alreadyPaired: return .alreadyPaired
        case .outgoingInviteAlreadyActive: return .activeOutgoingInviteExists
        case .cannotAcceptOwnInvite: return .cannotAcceptOwnInvite
        case .inviteAlreadyAccepted: return .inviteAlreadyAccepted
        case .alreadyPairedWithDifferentPartner(let name):
            return .mustStopToSwitchPartner(partnerName: name)
        }
    }

    private func mapServiceError(_ error: ScheduleSharingServiceError) -> ShareLinkErrorState? {
        switch error {
        case .alreadyPaired: return .inviteDisabledWhilePaired
        case .outgoingInviteAlreadyActive: return .activeOutgoingInviteExists
        default: return nil
        }
    }

    private func messageForCreateError(_ error: ScheduleSharingServiceError) -> String {
        switch error {
        case .alreadyPaired:
            return L10n("schedule.share.error.paired_cannot_create")
        case .outgoingInviteAlreadyActive:
            return L10n("schedule.share.error.active_link_exists")
        default:
            return L10n("schedule.share.error.create_failed")
        }
    }
}

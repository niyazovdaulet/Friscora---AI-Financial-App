import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
final class StatementImportHomeViewModel: ObservableObject {
    @Published var files: [ImportedStatementFile] = []
    @Published var showOnboarding = false
    @Published var dontShowOnboardingAgain = false
    @Published var showFileImporter = false
    @Published var scanningViewModel: StatementScanningViewModel?
    @Published var reviewViewModel: StatementImportReviewViewModel?
    @Published var activeAlert: HomeAlert?
    @Published var renameText = ""

    private let onboardingKey = "statement_import_onboarding_seen_v1"
    private let coordinator = StatementImportCoordinator()

    enum HomeAlert: Identifiable {
        case message(String)
        case rename(ImportedStatementFile)
        case delete(ImportedStatementFile)

        var id: String {
            switch self {
            case .message(let message): return "message_\(message)"
            case .rename(let file): return "rename_\(file.id.uuidString)"
            case .delete(let file): return "delete_\(file.id.uuidString)"
            }
        }
    }

    init() {
        loadFiles()
        showOnboarding = !UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func loadFiles() {
        files = coordinator.files()
    }

    func completeOnboarding() {
        if dontShowOnboardingAgain { UserDefaults.standard.set(true, forKey: onboardingKey) }
        showOnboarding = false
    }

    func skipOnboarding() {
        showOnboarding = false
    }

    func importSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            activeAlert = .message(error.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            let vm = StatementScanningViewModel(sourceFileURL: url, coordinator: coordinator)
            vm.onFinished = { [weak self] file, session in
                Task { @MainActor [weak self] in
                    await self?.presentReviewAfterScanDismiss(file: file, session: session)
                }
            }
            vm.onError = { [weak self] message in
                Task { @MainActor [weak self] in
                    self?.loadFiles()
                    // Keep error handling within scanning screen to avoid alert/sheet presentation races.
                    _ = message
                }
            }
            scanningViewModel = vm
        }
    }

    func openFile(_ file: ImportedStatementFile) {
        if let session = coordinator.session(for: file.id) {
            reviewViewModel = StatementImportReviewViewModel(file: file, session: session, coordinator: coordinator)
        } else {
            let vm = StatementScanningViewModel(existingFile: file, coordinator: coordinator)
            vm.onFinished = { [weak self] file, session in
                Task { @MainActor [weak self] in
                    await self?.presentReviewAfterScanDismiss(file: file, session: session)
                }
            }
            vm.onError = { [weak self] message in
                Task { @MainActor [weak self] in
                    self?.loadFiles()
                    _ = message
                }
            }
            scanningViewModel = vm
        }
    }

    func rescan(_ file: ImportedStatementFile) {
        let vm = StatementScanningViewModel(existingFile: file, coordinator: coordinator)
        vm.onFinished = { [weak self] file, session in
            Task { @MainActor [weak self] in
                await self?.presentReviewAfterScanDismiss(file: file, session: session)
            }
        }
        vm.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.loadFiles()
                _ = message
            }
        }
        scanningViewModel = vm
    }

    func beginRename(_ file: ImportedStatementFile) {
        activeAlert = .rename(file)
        renameText = file.displayName
    }

    func confirmRename() {
        guard case .rename(let file) = activeAlert else { return }
        coordinator.rename(file, to: renameText)
        activeAlert = nil
        loadFiles()
    }

    func confirmDelete(_ file: ImportedStatementFile) {
        activeAlert = .delete(file)
    }

    func deleteConfirmed() {
        guard case .delete(let file) = activeAlert else { return }
        coordinator.delete(file)
        activeAlert = nil
        loadFiles()
    }

    private func presentReviewAfterScanDismiss(file: ImportedStatementFile, session: StatementImportSession) async {
        scanningViewModel = nil
        loadFiles()
        // Wait a tick to avoid presenting while fullScreenCover is dismissing.
        try? await Task.sleep(nanoseconds: 220_000_000)
        reviewViewModel = StatementImportReviewViewModel(file: file, session: session, coordinator: coordinator)
    }
}

@MainActor
final class StatementScanningViewModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published var statusTitle = "Analyzing statement…"
    @Published var statusSubtitle = "Extracting pages…"
    @Published var failedMessage: String?
    @Published var displayName: String

    var onFinished: ((ImportedStatementFile, StatementImportSession) -> Void)?
    var onError: ((String) -> Void)?

    private let sourceFileURL: URL?
    private let existingFile: ImportedStatementFile?
    private let coordinator: StatementImportCoordinator

    init(sourceFileURL: URL, coordinator: StatementImportCoordinator) {
        self.sourceFileURL = sourceFileURL
        self.existingFile = nil
        self.coordinator = coordinator
        self.displayName = sourceFileURL.lastPathComponent
    }

    init(existingFile: ImportedStatementFile, coordinator: StatementImportCoordinator) {
        self.sourceFileURL = nil
        self.existingFile = existingFile
        self.coordinator = coordinator
        self.displayName = existingFile.displayName
    }

    /// Minimum time the scanning UI stays visible so the user sees the scan animation (fullScreenCover dismisses when `onFinished` runs).
    private static let minimumScanVisibleDuration: TimeInterval = 3.5

    func start() {
        Task {
            let scanFlowStartedAt = Date()
            do {
                let progress: StatementParserService.ParseProgressHandler = { [weak self] step in
                    Task { @MainActor in self?.statusSubtitle = step }
                }
                let file: ImportedStatementFile
                let session: StatementImportSession
                if let existingFile {
                    session = try coordinator.rescan(existingFile, progress: progress)
                    file = coordinator.files().first(where: { $0.id == existingFile.id }) ?? existingFile
                } else if let sourceFileURL {
                    (file, session) = try coordinator.importAndParseFile(from: sourceFileURL, progress: progress)
                } else {
                    return
                }
                let elapsed = Date().timeIntervalSince(scanFlowStartedAt)
                let remaining = max(0, Self.minimumScanVisibleDuration - elapsed)
                if remaining > 0 {
                    try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                }
                await MainActor.run {
                    onFinished?(file, session)
                }
            } catch {
                await MainActor.run {
                    failedMessage = error.localizedDescription
                    onError?(error.localizedDescription)
                }
            }
        }
    }
}

@MainActor
final class StatementImportReviewViewModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published var file: ImportedStatementFile
    @Published var session: StatementImportSession
    @Published var duplicateWarnings: [DuplicateTransactionWarning] = []
    @Published var showDuplicateDialog = false
    @Published var showSuccessSheet = false
    @Published var postCommitMessage: String?
    @Published var importedCount = 0
    @Published var editingTransaction: ParsedStatementTransaction?
    @Published var convertedTotalsHint: String?

    private let coordinator: StatementImportCoordinator
    private let reviewService: StatementImportReviewService
    private let learnedMerchantStore: MerchantLearningStoreProviding
    private var conversionTaskToken = 0

    init(file: ImportedStatementFile, session: StatementImportSession, coordinator: StatementImportCoordinator) {
        self.file = file
        self.session = session
        self.coordinator = coordinator
        self.reviewService = coordinator.reviewServiceInstance()
        self.learnedMerchantStore = LearnedMerchantStore.shared
        refreshDuplicateWarnings()
        refreshConvertedTotalsHint()
    }

    var selectedCount: Int { session.selectedTransactionIDs.count }
    var selectedIncomeTotal: Double { reviewService.selectedIncomeTotal(in: session) }
    var selectedExpenseTotal: Double { reviewService.selectedExpenseTotal(in: session) }
    var selectedIncomeTotalsByCurrency: [(currency: String, amount: Double)] {
        aggregateSelectedTotals(direction: .income)
    }
    var selectedExpenseTotalsByCurrency: [(currency: String, amount: Double)] {
        aggregateSelectedTotals(direction: .expense)
    }
    var selectedIncomeDisplayText: String {
        formattedTotalsText(selectedIncomeTotalsByCurrency)
    }
    var selectedExpenseDisplayText: String {
        formattedTotalsText(selectedExpenseTotalsByCurrency)
    }

    func isSelected(_ tx: ParsedStatementTransaction) -> Bool {
        session.selectedTransactionIDs.contains(tx.id)
    }

    func toggleSelection(_ tx: ParsedStatementTransaction) {
        if session.selectedTransactionIDs.contains(tx.id) {
            session.selectedTransactionIDs.remove(tx.id)
        } else {
            session.selectedTransactionIDs.insert(tx.id)
        }
        updateDerivedSelection()
    }

    func selectAll() {
        session.selectedTransactionIDs = Set(session.parsedTransactions.map(\.id))
        updateDerivedSelection()
    }

    func deselectAll() {
        session.selectedTransactionIDs.removeAll()
        updateDerivedSelection()
    }

    func removeSelected() {
        session.parsedTransactions.removeAll { session.selectedTransactionIDs.contains($0.id) }
        session.selectedTransactionIDs.removeAll()
        updateDerivedSelection()
    }

    func removeTransaction(_ tx: ParsedStatementTransaction) {
        session.parsedTransactions.removeAll { $0.id == tx.id }
        session.selectedTransactionIDs.remove(tx.id)
        updateDerivedSelection()
    }

    func updateTransaction(_ updated: ParsedStatementTransaction) {
        guard let idx = session.parsedTransactions.firstIndex(where: { $0.id == updated.id }) else { return }
        if updated.isCategorizationManuallyOverridden == true {
            learnedMerchantStore.saveManualOverride(
                transactionDescription: updated.rawDescription,
                builtInCategory: updated.suggestedBuiltInCategory,
                customCategoryID: updated.suggestedCustomCategoryID
            )
        }
        session.parsedTransactions[idx] = updated
        updateDerivedSelection()
    }

    func beginCommit() {
        refreshDuplicateWarnings()
        if duplicateWarnings.isEmpty {
            commit(skipDuplicates: false)
        } else {
            showDuplicateDialog = true
        }
    }

    func commit(skipDuplicates: Bool) {
        showDuplicateDialog = false
        let skipIDs = skipDuplicates ? Set(duplicateWarnings.map(\.parsedTransactionID)) : []
        importedCount = coordinator.commit(file: file, session: session, skipDuplicateIDs: skipIDs)
        if importedCount == 0 {
            postCommitMessage = "No new transactions were imported. All selected rows look like duplicates."
            return
        }
        showSuccessSheet = true
    }

    private func updateDerivedSelection() {
        for idx in session.parsedTransactions.indices {
            let txID = session.parsedTransactions[idx].id
            session.parsedTransactions[idx].isSelected = session.selectedTransactionIDs.contains(txID)
        }
        refreshDuplicateWarnings()
        refreshConvertedTotalsHint()
        session.updatedAt = Date()
        coordinator.updateSession(session)
    }

    func refreshDuplicateWarnings() {
        duplicateWarnings = coordinator.detectDuplicates(for: session)
    }

    private func refreshConvertedTotalsHint() {
        let selected = session.parsedTransactions.filter { session.selectedTransactionIDs.contains($0.id) }
        let selectedCurrencies = Set(selected.map(\.currency))
        let targetCurrency = UserProfileService.shared.profile.currency
        guard selectedCurrencies.count > 1 else {
            convertedTotalsHint = nil
            return
        }

        conversionTaskToken += 1
        let token = conversionTaskToken
        Task {
            let currencyService = CurrencyService.shared
            var incomeTotal: Double = 0
            var expenseTotal: Double = 0
            var hadFailure = false

            for tx in selected {
                let converted: Double
                if tx.currency == targetCurrency {
                    converted = tx.absoluteAmount
                } else {
                    do {
                        converted = try await currencyService.convert(
                            amount: tx.absoluteAmount,
                            from: tx.currency,
                            to: targetCurrency
                        )
                    } catch {
                        hadFailure = true
                        converted = tx.absoluteAmount
                    }
                }
                if tx.direction == .income {
                    incomeTotal += converted
                } else {
                    expenseTotal += converted
                }
            }

            await MainActor.run {
                guard token == self.conversionTaskToken else { return }
                let income = CurrencyFormatter.format(incomeTotal, currencyCode: targetCurrency)
                let expenses = CurrencyFormatter.format(expenseTotal, currencyCode: targetCurrency)
                var hint = "~ Converted to \(targetCurrency): Income \(income) • Expenses \(expenses)"
                if hadFailure {
                    hint += " (some rates unavailable)"
                }
                self.convertedTotalsHint = hint
            }
        }
    }

    private func aggregateSelectedTotals(direction: ParsedTransactionDirection) -> [(currency: String, amount: Double)] {
        var totals: [String: Double] = [:]
        for tx in session.parsedTransactions where
            session.selectedTransactionIDs.contains(tx.id) && tx.direction == direction {
            totals[tx.currency, default: 0] += tx.absoluteAmount
        }
        return totals
            .map { (currency: $0.key, amount: $0.value) }
            .sorted { $0.currency < $1.currency }
    }

    private func formattedTotalsText(_ totals: [(currency: String, amount: Double)]) -> String {
        guard !totals.isEmpty else {
            return CurrencyFormatter.format(0, currencyCode: UserProfileService.shared.profile.currency)
        }
        return totals
            .map { CurrencyFormatter.format($0.amount, currencyCode: $0.currency) }
            .joined(separator: " • ")
    }
}

@MainActor
final class StatementTransactionEditViewModel: ObservableObject {
    struct CategoryOption: Identifiable {
        let id: String
        let title: String
        let builtInCategory: ExpenseCategory?
        let customCategoryID: UUID?
    }

    @Published var description: String
    @Published var amount: String
    @Published var date: Date
    @Published var currency: String
    @Published var direction: ParsedTransactionDirection
    @Published var selectedCategoryID: String
    @Published var error: String?

    private let transaction: ParsedStatementTransaction
    var previewTransaction: ParsedStatementTransaction { transaction }
    let categoryOptions: [CategoryOption]

    init(transaction: ParsedStatementTransaction) {
        self.transaction = transaction
        self.description = transaction.displayDescription
        self.amount = String(format: "%.2f", transaction.absoluteAmount)
        self.date = transaction.date
        self.currency = transaction.currency
        self.direction = transaction.direction
        let snapshot = CategorySnapshotProvider().activeCategorySnapshot()
        self.categoryOptions = snapshot.map { reference in
            CategoryOption(
                id: reference.id,
                title: reference.displayName,
                builtInCategory: reference.builtInCategory,
                customCategoryID: reference.customCategoryID
            )
        }
        self.selectedCategoryID = StatementTransactionEditViewModel.initialCategoryID(
            from: transaction,
            options: self.categoryOptions
        )
    }

    func buildUpdated() -> ParsedStatementTransaction? {
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Description is required."
            return nil
        }
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else {
            error = "Amount must be valid."
            return nil
        }
        guard currency.count >= 3 else {
            error = "Currency should be valid."
            return nil
        }
        var updated = transaction
        updated.displayDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.normalizedDescription = description.lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        updated.date = date
        updated.currency = currency.uppercased()
        updated.direction = direction
        updated.amount = (direction == .expense ? -1 : 1) * value
        updated.absoluteAmount = value
        updated.isEdited = true
        if direction == .expense {
            let selected = categoryOptions.first(where: { $0.id == selectedCategoryID })
            updated.suggestedBuiltInCategory = selected?.builtInCategory
            updated.suggestedCustomCategoryID = selected?.customCategoryID
            updated.categorizationSource = .manual
            updated.categorizationReasons = ["Selected manually during statement review."]
            updated.categorizationConfidence = 1.0
            updated.isCategorizationManuallyOverridden = true
        } else {
            updated.suggestedBuiltInCategory = nil
            updated.suggestedCustomCategoryID = nil
            updated.categorizationSource = nil
            updated.categorizationReasons = nil
            updated.categorizationConfidence = nil
            updated.isCategorizationManuallyOverridden = nil
        }
        return updated
    }

    private static func initialCategoryID(
        from transaction: ParsedStatementTransaction,
        options: [CategoryOption]
    ) -> String {
        if let customID = transaction.suggestedCustomCategoryID {
            let id = "custom:\(customID.uuidString)"
            if options.contains(where: { $0.id == id }) { return id }
        }
        if let builtIn = transaction.suggestedBuiltInCategory {
            let id = "builtin:\(builtIn.rawValue)"
            if options.contains(where: { $0.id == id }) { return id }
        }
        if options.contains(where: { $0.id == "builtin:\(ExpenseCategory.other.rawValue)" }) {
            return "builtin:\(ExpenseCategory.other.rawValue)"
        }
        return options.first?.id ?? ""
    }
}

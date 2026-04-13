import SwiftUI
import UniformTypeIdentifiers

private struct SuggestedCategoryDisplay {
    let label: String
    let confidence: Double
    let band: CategorizationConfidenceBand
}

private enum SuggestedCategoryPresenter {
    static func display(for tx: ParsedStatementTransaction) -> SuggestedCategoryDisplay? {
        guard tx.direction == .expense,
              let confidence = tx.categorizationConfidence else {
            return nil
        }

        let label: String?
        if let builtIn = tx.suggestedBuiltInCategory {
            label = builtIn.localizedName
        } else if let customID = tx.suggestedCustomCategoryID {
            label = CustomCategoryService.shared.customCategories.first(where: { $0.id == customID })?.name
        } else {
            label = nil
        }
        guard let label else { return nil }
        return SuggestedCategoryDisplay(
            label: label,
            confidence: confidence,
            band: CategorizationThresholds.band(for: confidence)
        )
    }

    static func confidenceTitle(_ band: CategorizationConfidenceBand) -> String {
        switch band {
        case .high: return "High confidence"
        case .medium: return "Medium confidence"
        case .low: return "Low confidence"
        }
    }

    static func bandColor(_ band: CategorizationConfidenceBand) -> Color {
        switch band {
        case .high: return AppColorTheme.accent
        case .medium: return AppColorTheme.textSecondary
        case .low: return AppColorTheme.negative
        }
    }
}

private struct SuggestedCategoryChip: View {
    let display: SuggestedCategoryDisplay

    var body: some View {
        HStack(spacing: 6) {
            Text(display.label)
            Text("•")
            Text(SuggestedCategoryPresenter.confidenceTitle(display.band))
        }
        .font(AppTypography.caption)
        .foregroundColor(SuggestedCategoryPresenter.bandColor(display.band))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(SuggestedCategoryPresenter.bandColor(display.band).opacity(0.14))
        )
    }
}

struct StatementImportHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StatementImportHomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        header
                        privacyChip
                        if viewModel.files.isEmpty {
                            emptyState
                        } else {
                            primaryCTA
                            recentSection
                        }
                    }
                    .padding(AppSpacing.m)
                }
            }
            .navigationTitle("Statement Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showOnboarding) {
                StatementImportPrivacySheet(
                    dontShowAgain: $viewModel.dontShowOnboardingAgain,
                    onContinue: { viewModel.completeOnboarding() },
                    onNotNow: { viewModel.skipOnboarding() }
                )
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(24)
            }
            .fileImporter(
                isPresented: $viewModel.showFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false,
                onCompletion: viewModel.importSelection
            )
            .fullScreenCover(item: $viewModel.scanningViewModel) { scanning in
                StatementScanningView(viewModel: scanning)
            }
            .sheet(item: $viewModel.reviewViewModel) { review in
                StatementImportReviewView(viewModel: review) {
                    viewModel.loadFiles()
                }
            }
            .alert("Statement Import", isPresented: Binding(
                get: {
                    if case .message = viewModel.activeAlert { return true }
                    return false
                },
                set: { showing in
                    if !showing, case .message = viewModel.activeAlert { viewModel.activeAlert = nil }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if case .message(let message) = viewModel.activeAlert {
                    Text(message)
                } else {
                    Text("")
                }
            }
            .alert("Rename Statement", isPresented: Binding(
                get: {
                    if case .rename = viewModel.activeAlert { return true }
                    return false
                },
                set: { showing in
                    if !showing, case .rename = viewModel.activeAlert { viewModel.activeAlert = nil }
                }
            )) {
                TextField("New name", text: $viewModel.renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") { viewModel.confirmRename() }
            }
            .alert("Delete statement?", isPresented: Binding(
                get: {
                    if case .delete = viewModel.activeAlert { return true }
                    return false
                },
                set: { showing in
                    if !showing, case .delete = viewModel.activeAlert { viewModel.activeAlert = nil }
                }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { viewModel.deleteConfirmed() }
            } message: {
                Text("This deletes the PDF and its review session from this device, and removes every expense and income that was imported from this statement from your history and dashboard.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Import transactions from bank statement PDFs")
                .font(AppTypography.bodySecondary)
                .foregroundColor(AppColorTheme.textSecondary)
        }
    }

    private var privacyChip: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "lock.shield")
            Text("On-device only")
        }
        .font(AppTypography.captionMedium)
        .foregroundColor(AppColorTheme.accent)
        .padding(.horizontal, AppSpacing.s)
        .padding(.vertical, 7)
        .background(Capsule().fill(AppColorTheme.accent.opacity(0.15)))
    }

    private var primaryCTA: some View {
        Button("Import PDF Statement") { viewModel.showFileImporter = true }
            .buttonStyle(PrimaryCTAButtonStyle())
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("No statements imported yet")
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
            Text("Upload a PDF bank statement from your bank app and Friscora will detect your transactions for review.")
                .font(AppTypography.bodySecondary)
                .foregroundColor(AppColorTheme.textSecondary)
            Button("Import PDF Statement") { viewModel.showFileImporter = true }
                .buttonStyle(PrimaryCTAButtonStyle())
            Text("Only PDF bank statements are supported for now")
                .font(AppTypography.caption)
                .foregroundColor(AppColorTheme.textTertiary)
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColorTheme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColorTheme.cardBorder))
        )
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Recent Imports")
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)

            ForEach(viewModel.files) { file in
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.displayName)
                                .font(AppTypography.bodySemibold)
                                .foregroundColor(AppColorTheme.textPrimary)
                            Text(file.importedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                        }
                        Spacer()
                        Text(file.status.rawValue)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColorTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppColorTheme.accent.opacity(0.15)))
                    }
                    HStack {
                        Text("\(file.transactionCount) tx")
                        Spacer()
                        Text("+\(formattedImportTotal(file.totalIncome, for: file))")
                            .foregroundColor(AppColorTheme.incomeIndicator)
                        Text("-\(formattedImportTotal(file.totalExpense, for: file))")
                            .foregroundColor(AppColorTheme.expenseIndicator)
                    }
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColorTheme.textSecondary)

                    HStack(spacing: AppSpacing.s) {
                        Button("Open") { viewModel.openFile(file) }
                            .buttonStyle(SecondaryCTAButtonStyle())
                        Button("Re-scan") { viewModel.rescan(file) }
                            .buttonStyle(SecondaryCTAButtonStyle())
                    }
                    Menu {
                        Button("Rename") { viewModel.beginRename(file) }
                        Button("Delete", role: .destructive) { viewModel.confirmDelete(file) }
                    } label: {
                        Label("Manage", systemImage: "ellipsis.circle")
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
                .padding(AppSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.cardMedium)
                        .fill(AppColorTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.cardMedium).stroke(AppColorTheme.cardBorder))
                )
            }
        }
    }

    private func formattedImportTotal(_ amount: Double, for file: ImportedStatementFile) -> String {
        let currencies = Array(file.currencySet).sorted()
        if let only = currencies.first, currencies.count == 1 {
            return CurrencyFormatter.format(amount, currencyCode: only)
        }
        // A file can theoretically contain mixed currencies; avoid falsely labeling with app currency.
        let label = currencies.isEmpty ? UserProfileService.shared.profile.currency : currencies.joined(separator: "/")
        return CurrencyFormatter.format(amount, currencyCode: label)
    }
}

struct StatementImportPrivacySheet: View {
    @Binding var dontShowAgain: Bool
    let onContinue: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ZStack {
            AppColorTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Import bank statements securely")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColorTheme.textPrimary)
                Group {
                    Text("• Import PDF statements from your bank")
                    Text("• Friscora automatically detects transactions")
                    Text("• Review everything before adding")
                    Text("• Processing happens on your device")
                    Text("• Your files are never uploaded to servers")
                    Text("• You can delete imported statements anytime")
                }
                .font(AppTypography.bodySecondary)
                .foregroundColor(AppColorTheme.textSecondary)

                Toggle("Don't show again", isOn: $dontShowAgain)
                    .tint(AppColorTheme.accent)
                    .foregroundColor(AppColorTheme.textPrimary)

                Button("Continue", action: onContinue)
                    .buttonStyle(PrimaryCTAButtonStyle())
                Button("Not now", action: onNotNow)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
            .padding(AppSpacing.m)
        }
    }
}

struct StatementScanningView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StatementScanningViewModel
    @State private var scanY: CGFloat = -120

    var body: some View {
        ZStack {
            LinearGradient(colors: [AppColorTheme.background, AppColorTheme.cardBackground], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: AppSpacing.l) {
                Text(viewModel.statusTitle)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColorTheme.textPrimary)
                Text(viewModel.statusSubtitle)
                    .font(AppTypography.bodySecondary)
                    .foregroundColor(AppColorTheme.textSecondary)

                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(AppColorTheme.cardBackground)
                    .frame(height: 260)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColorTheme.cardBorder))
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundColor(AppColorTheme.textSecondary)
                            Text(viewModel.displayName)
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColorTheme.textSecondary)
                                .lineLimit(1)
                        }
                    )
                    .overlay {
                        GeometryReader { proxy in
                            let cardHeight: CGFloat = proxy.size.height
                            let lineHeight: CGFloat = 4
                            let maxTravel = max(0, cardHeight - lineHeight)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppColorTheme.accent)
                                .frame(height: lineHeight)
                                .shadow(color: AppColorTheme.accent.opacity(0.9), radius: 8)
                                .offset(y: scanY)
                                .onAppear {
                                    scanY = 0
                                    withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: true)) {
                                        scanY = maxTravel
                                    }
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .padding(.horizontal, AppSpacing.m)
                if let failed = viewModel.failedMessage {
                    Text(failed)
                        .font(AppTypography.bodySecondary)
                        .foregroundColor(AppColorTheme.negative)
                    Button("Close") { dismiss() }
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
            .padding(AppSpacing.m)
        }
        .task { viewModel.start() }
        .onReceive(viewModel.$failedMessage) { value in
            if value != nil { scanY = -120 }
        }
        // Scan screen stays up until `onFinished` fires; home VM clears `scanningViewModel` only after
        // `StatementScanningViewModel` enforces minimum visible duration (see ViewModel).
    }
}

struct StatementImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StatementImportReviewViewModel
    let onImportDone: () -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppColorTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppSpacing.m) {
                        summaryCard
                        actionBar
                        transactionsList
                    }
                    .padding(AppSpacing.m)
                    .padding(.bottom, 96)
                }
                bottomCTA
            }
            .navigationTitle("Review Transactions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(item: $viewModel.editingTransaction) { tx in
                StatementTransactionEditSheet(transaction: tx) { updated in
                    viewModel.updateTransaction(updated)
                }
            }
            .confirmationDialog("Potential duplicates detected", isPresented: $viewModel.showDuplicateDialog) {
                Button("Skip Duplicates") { viewModel.commit(skipDuplicates: true) }
                Button("Import Anyway") { viewModel.commit(skipDuplicates: false) }
                Button("Review Selection", role: .cancel) {}
            } message: {
                Text("\(viewModel.duplicateWarnings.count) transactions may already exist.")
            }
            .sheet(isPresented: $viewModel.showSuccessSheet) {
                StatementImportSuccessView(importedCount: viewModel.importedCount) {
                    onImportDone()
                    dismiss()
                }
            }
            .alert("Statement Import", isPresented: Binding(
                get: { viewModel.postCommitMessage != nil },
                set: { showing in if !showing { viewModel.postCommitMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.postCommitMessage ?? "")
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.file.displayName)
                .font(AppTypography.bodySemibold)
                .foregroundColor(AppColorTheme.textPrimary)
            Text("Detected: \(viewModel.session.parsedTransactions.count) • Selected: \(viewModel.selectedCount)")
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.textSecondary)
            HStack {
                Text("Income \(viewModel.selectedIncomeDisplayText)")
                    .foregroundColor(AppColorTheme.incomeIndicator)
                Spacer()
                Text("Expenses \(viewModel.selectedExpenseDisplayText)")
                    .foregroundColor(AppColorTheme.expenseIndicator)
            }
            .font(AppTypography.captionMedium)
            if let convertedHint = viewModel.convertedTotalsHint {
                Text(convertedHint)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            HStack(spacing: 8) {
                Label("Processed on-device", systemImage: "lock.shield")
                if !viewModel.duplicateWarnings.isEmpty {
                    Label("\(viewModel.duplicateWarnings.count) possible duplicates", systemImage: "exclamationmark.triangle")
                }
            }
            .font(AppTypography.caption)
            .foregroundColor(AppColorTheme.textTertiary)
        }
        .padding(AppSpacing.m)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(AppColorTheme.cardBackground).overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColorTheme.cardBorder)))
    }

    private var actionBar: some View {
        HStack(spacing: AppSpacing.s) {
            Button("Select all") { viewModel.selectAll() }
            Button("Deselect all") { viewModel.deselectAll() }
            Button("Remove selected", role: .destructive) { viewModel.removeSelected() }
        }
        .font(AppTypography.captionMedium)
        .foregroundColor(AppColorTheme.textSecondary)
    }

    private var transactionsList: some View {
        let duplicateIDs = Set(viewModel.duplicateWarnings.map(\.parsedTransactionID))
        return LazyVStack(spacing: AppSpacing.s) {
            ForEach(viewModel.session.parsedTransactions) { tx in
                let isDuplicate = duplicateIDs.contains(tx.id)
                HStack(spacing: AppSpacing.s) {
                    Button {
                        viewModel.toggleSelection(tx)
                    } label: {
                        Image(systemName: viewModel.isSelected(tx) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.isSelected(tx) ? AppColorTheme.accent : AppColorTheme.textTertiary)
                            .font(.title3)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tx.displayDescription)
                            .font(AppTypography.bodySecondary)
                            .foregroundColor(AppColorTheme.textPrimary)
                            .lineLimit(2)
                        HStack {
                            Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                            Text(tx.currency)
                            Text(tx.direction == .income ? "Income" : "Expense")
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                        if isDuplicate {
                            Label("Possible duplicate", systemImage: "exclamationmark.triangle.fill")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColorTheme.negative)
                        }
                        if let suggestion = SuggestedCategoryPresenter.display(for: tx) {
                            SuggestedCategoryChip(display: suggestion)
                        }
                    }
                    Spacer()
                    Text(CurrencyFormatter.format(tx.absoluteAmount, currencyCode: tx.currency))
                        .font(AppTypography.bodySemibold)
                        .foregroundColor(tx.direction == .income ? AppColorTheme.incomeIndicator : AppColorTheme.expenseIndicator)
                }
                .padding(AppSpacing.s)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.cardMedium)
                        .fill(AppColorTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.cardMedium)
                                .stroke(isDuplicate ? AppColorTheme.negative.opacity(0.5) : AppColorTheme.cardBorder)
                        )
                )
                .onTapGesture { viewModel.editingTransaction = tx }
                .swipeActions {
                    Button(role: .destructive) {
                        viewModel.removeTransaction(tx)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: 8) {
            Button("Import Selected Transactions (\(viewModel.selectedCount))") {
                viewModel.beginCommit()
            }
            .buttonStyle(PrimaryCTAButtonStyle())
        }
        .padding(AppSpacing.m)
        .background(.ultraThinMaterial)
    }
}

struct StatementTransactionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: StatementTransactionEditViewModel
    let onSave: (ParsedStatementTransaction) -> Void

    init(transaction: ParsedStatementTransaction, onSave: @escaping (ParsedStatementTransaction) -> Void) {
        _viewModel = StateObject(wrappedValue: StatementTransactionEditViewModel(transaction: transaction))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Description") { TextField("Description", text: $viewModel.description) }
                Section("Amount") { TextField("0.00", text: $viewModel.amount).keyboardType(.decimalPad) }
                Section("Date") { DatePicker("Date", selection: $viewModel.date, displayedComponents: .date) }
                Section("Currency") { TextField("USD", text: $viewModel.currency) }
                Section("Type") {
                    Picker("Type", selection: $viewModel.direction) {
                        Text("Income").tag(ParsedTransactionDirection.income)
                        Text("Expense").tag(ParsedTransactionDirection.expense)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Category") {
                    if viewModel.direction == .expense {
                        Picker("Category", selection: $viewModel.selectedCategoryID) {
                            ForEach(viewModel.categoryOptions) { option in
                                Text(option.title).tag(option.id)
                            }
                        }
                    } else {
                        Text("Not used for income imports yet")
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
                if let suggestion = SuggestedCategoryPresenter.display(for: viewModel.previewTransaction) {
                    Section("Suggested Category (Read-only)") {
                        SuggestedCategoryChip(display: suggestion)
                        if let source = viewModel.previewTransaction.categorizationSource {
                            Text(sourceLabel(source))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                        }
                    }
                }
                if let error = viewModel.error {
                    Section { Text(error).foregroundColor(AppColorTheme.negative) }
                }
            }
            .navigationTitle("Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let updated = viewModel.buildUpdated() else { return }
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }

    private func sourceLabel(_ source: CategorizationSource) -> String {
        switch source {
        case .custom: return "Source: Custom category"
        case .builtIn: return "Source: Built-in category"
        case .manual: return "Source: Manual override"
        }
    }
}

struct StatementImportSuccessView: View {
    let importedCount: Int
    let onDone: () -> Void

    var body: some View {
        ZStack {
            AppColorTheme.background.ignoresSafeArea()
            VStack(spacing: AppSpacing.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(AppColorTheme.accent)
                Text("\(importedCount) transactions imported")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColorTheme.textPrimary)
                Text("Your balance, recent activity, and analytics have been updated.")
                    .font(AppTypography.bodySecondary)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Done", action: onDone)
                    .buttonStyle(PrimaryCTAButtonStyle())
            }
            .padding(AppSpacing.m)
        }
    }
}

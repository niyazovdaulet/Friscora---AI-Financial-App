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
        case .high: return L10n("statement.import.categorization.confidence.high")
        case .medium: return L10n("statement.import.categorization.confidence.medium")
        case .low: return L10n("statement.import.categorization.confidence.low")
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
    @Binding var selectedTab: Int
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
            .navigationTitle(L10n("statement.import.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.done")) { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showOnboarding) {
                StatementImportPrivacySheet(
                    dontShowAgain: $viewModel.dontShowOnboardingAgain,
                    onContinue: { viewModel.completeOnboarding() },
                    onNotNow: {
                        viewModel.skipOnboarding()
                        selectedTab = 0
                        dismiss()
                    }
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
            .alert(L10n("statement.import.title"), isPresented: Binding(
                get: {
                    if case .message = viewModel.activeAlert { return true }
                    return false
                },
                set: { showing in
                    if !showing, case .message = viewModel.activeAlert { viewModel.activeAlert = nil }
                }
            )) {
                Button(L10n("common.ok"), role: .cancel) {}
            } message: {
                if case .message(let message) = viewModel.activeAlert {
                    Text(message)
                } else {
                    Text("")
                }
            }
            .alert(L10n("statement.import.rename_title"), isPresented: Binding(
                get: {
                    if case .rename = viewModel.activeAlert { return true }
                    return false
                },
                set: { showing in
                    if !showing, case .rename = viewModel.activeAlert { viewModel.activeAlert = nil }
                }
            )) {
                TextField(L10n("statement.import.rename_placeholder"), text: $viewModel.renameText)
                Button(L10n("common.cancel"), role: .cancel) {}
                Button(L10n("common.save")) { viewModel.confirmRename() }
            }
            .alert(L10n("statement.import.delete_confirm_title"), isPresented: Binding(
                get: {
                    if case .delete = viewModel.activeAlert { return true }
                    return false
                },
                set: { showing in
                    if !showing, case .delete = viewModel.activeAlert { viewModel.activeAlert = nil }
                }
            )) {
                Button(L10n("common.cancel"), role: .cancel) {}
                Button(L10n("common.delete"), role: .destructive) { viewModel.deleteConfirmed() }
            } message: {
                Text(L10n("statement.import.delete_confirm_message"))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(L10n("statement.import.header_subtitle"))
                .font(AppTypography.bodySecondary)
                .foregroundColor(AppColorTheme.textSecondary)
        }
    }

    private var privacyChip: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "lock.shield")
            Text(L10n("statement.import.privacy_chip"))
        }
        .font(AppTypography.captionMedium)
        .foregroundColor(AppColorTheme.accent)
        .padding(.horizontal, AppSpacing.s)
        .padding(.vertical, 7)
        .background(Capsule().fill(AppColorTheme.accent.opacity(0.15)))
    }

    private var primaryCTA: some View {
        Button(L10n("statement.import.import_pdf")) { viewModel.showFileImporter = true }
            .buttonStyle(PrimaryCTAButtonStyle())
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(L10n("statement.import.empty_title"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
            Text(L10n("statement.import.empty_body"))
                .font(AppTypography.bodySecondary)
                .foregroundColor(AppColorTheme.textSecondary)
            Button(L10n("statement.import.import_pdf")) { viewModel.showFileImporter = true }
                .buttonStyle(PrimaryCTAButtonStyle())
            Text(L10n("statement.import.supported_footer"))
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
            Text(L10n("statement.import.recent_section"))
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
                        Text(file.status.localizedName)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColorTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppColorTheme.accent.opacity(0.15)))
                    }
                    HStack {
                        Text(String(format: L10n("statement.import.transaction_count_format"), file.transactionCount))
                        Spacer()
                        Text("+\(formattedImportTotal(file.totalIncome, for: file))")
                            .foregroundColor(AppColorTheme.incomeIndicator)
                        Text("-\(formattedImportTotal(file.totalExpense, for: file))")
                            .foregroundColor(AppColorTheme.expenseIndicator)
                    }
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColorTheme.textSecondary)

                    HStack(spacing: AppSpacing.s) {
                        Button(L10n("statement.import.open")) { viewModel.openFile(file) }
                            .buttonStyle(SecondaryCTAButtonStyle())
                        Button(L10n("statement.import.rescan")) { viewModel.rescan(file) }
                            .buttonStyle(SecondaryCTAButtonStyle())
                    }
                    Menu {
                        Button(L10n("statement.import.rename")) { viewModel.beginRename(file) }
                        Button(L10n("common.delete"), role: .destructive) { viewModel.confirmDelete(file) }
                    } label: {
                        Label(L10n("statement.import.manage"), systemImage: "ellipsis.circle")
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
                Text(L10n("statement.import.privacy_sheet_title"))
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColorTheme.textPrimary)
                Group {
                    Text(L10n("statement.import.privacy_bullet.pdf"))
                    Text(L10n("statement.import.privacy_bullet.detect"))
                    Text(L10n("statement.import.privacy_bullet.review"))
                    Text(L10n("statement.import.privacy_bullet.on_device"))
                    Text(L10n("statement.import.privacy_bullet.no_upload"))
                    Text(L10n("statement.import.privacy_bullet.delete_anytime"))
                }
                .font(AppTypography.bodySecondary)
                .foregroundColor(AppColorTheme.textSecondary)

                Toggle(L10n("statement.import.dont_show_again"), isOn: $dontShowAgain)
                    .tint(AppColorTheme.accent)
                    .foregroundColor(AppColorTheme.textPrimary)

                Button(L10n("statement.import.continue"), action: onContinue)
                    .buttonStyle(PrimaryCTAButtonStyle())
                Button(L10n("statement.import.not_now"), action: onNotNow)
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
                    Button(L10n("statement.import.close")) { dismiss() }
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
            .navigationTitle(L10n("statement.import.review_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n("statement.import.close")) { dismiss() } }
            }
            .sheet(item: $viewModel.editingTransaction) { tx in
                StatementTransactionEditSheet(transaction: tx) { updated in
                    viewModel.updateTransaction(updated)
                }
            }
            .confirmationDialog(L10n("statement.import.duplicates.title"), isPresented: $viewModel.showDuplicateDialog) {
                Button(L10n("statement.import.duplicates.skip")) { viewModel.commit(skipDuplicates: true) }
                Button(L10n("statement.import.duplicates.import_anyway")) { viewModel.commit(skipDuplicates: false) }
                Button(L10n("statement.import.duplicates.review"), role: .cancel) {}
            } message: {
                Text(duplicateDialogMessage(count: viewModel.duplicateWarnings.count))
            }
            .sheet(isPresented: $viewModel.showSuccessSheet) {
                StatementImportSuccessView(importedCount: viewModel.importedCount) {
                    onImportDone()
                    dismiss()
                }
            }
            .alert(L10n("statement.import.title"), isPresented: Binding(
                get: { viewModel.postCommitMessage != nil },
                set: { showing in if !showing { viewModel.postCommitMessage = nil } }
            )) {
                Button(L10n("common.ok"), role: .cancel) {}
            } message: {
                Text(viewModel.postCommitMessage ?? "")
            }
        }
    }

    private func duplicateDialogMessage(count: Int) -> String {
        count == 1
            ? L10n("statement.import.duplicates.message_one")
            : String(format: L10n("statement.import.duplicates.message_many"), count)
    }

    private func possibleDuplicatesLabel(count: Int) -> String {
        count == 1
            ? L10n("statement.import.review.possible_duplicates_one")
            : String(format: L10n("statement.import.review.possible_duplicates_many"), count)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.file.displayName)
                .font(AppTypography.bodySemibold)
                .foregroundColor(AppColorTheme.textPrimary)
            Text(
                String(
                    format: L10n("statement.import.review.detected_selected"),
                    viewModel.session.parsedTransactions.count,
                    viewModel.selectedCount
                )
            )
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.textSecondary)
            HStack {
                Text(String(format: L10n("statement.import.review.income_label"), viewModel.selectedIncomeDisplayText))
                    .foregroundColor(AppColorTheme.incomeIndicator)
                Spacer()
                Text(String(format: L10n("statement.import.review.expenses_label"), viewModel.selectedExpenseDisplayText))
                    .foregroundColor(AppColorTheme.expenseIndicator)
            }
            .font(AppTypography.captionMedium)
            if let convertedHint = viewModel.convertedTotalsHint {
                Text(convertedHint)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            if !viewModel.session.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(viewModel.session.warnings.enumerated()), id: \.offset) { _, warning in
                        Text(localizedStatementImportSessionWarning(warning))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColorTheme.textTertiary)
                    }
                }
            }
            HStack(spacing: 8) {
                Label(L10n("statement.import.review.processed_on_device"), systemImage: "lock.shield")
                if !viewModel.duplicateWarnings.isEmpty {
                    Label(possibleDuplicatesLabel(count: viewModel.duplicateWarnings.count), systemImage: "exclamationmark.triangle")
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
            Button(L10n("statement.import.review.select_all")) { viewModel.selectAll() }
            Button(L10n("statement.import.review.deselect_all")) { viewModel.deselectAll() }
            Button(L10n("statement.import.review.remove_selected"), role: .destructive) { viewModel.removeSelected() }
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
                            Text(tx.direction == .income ? L10n("statement.import.direction.income") : L10n("statement.import.direction.expense"))
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                        if isDuplicate {
                            Label(L10n("statement.import.duplicate.possible"), systemImage: "exclamationmark.triangle.fill")
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
                        Label(L10n("common.delete"), systemImage: "trash")
                    }
                }
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: 8) {
            Button(String(format: L10n("statement.import.review.import_selected_format"), viewModel.selectedCount)) {
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
                Section {
                    TextField(L10n("statement.import.edit.description_placeholder"), text: $viewModel.description)
                } header: {
                    Text(L10n("statement.import.edit.description_section"))
                }
                Section {
                    TextField(L10n("statement.import.edit.amount_placeholder"), text: $viewModel.amount).keyboardType(.decimalPad)
                } header: {
                    Text(L10n("statement.import.edit.amount_section"))
                }
                Section {
                    DatePicker(L10n("statement.import.edit.date_label"), selection: $viewModel.date, displayedComponents: .date)
                } header: {
                    Text(L10n("statement.import.edit.date_section"))
                }
                Section {
                    TextField(L10n("statement.import.edit.currency_placeholder"), text: $viewModel.currency)
                } header: {
                    Text(L10n("statement.import.edit.currency_section"))
                }
                Section {
                    Picker(L10n("statement.import.edit.type_label"), selection: $viewModel.direction) {
                        Text(L10n("statement.import.direction.income")).tag(ParsedTransactionDirection.income)
                        Text(L10n("statement.import.direction.expense")).tag(ParsedTransactionDirection.expense)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(L10n("statement.import.edit.type_section"))
                }
                Section {
                    if viewModel.direction == .expense {
                        Picker(L10n("statement.import.edit.category_label"), selection: $viewModel.selectedCategoryID) {
                            ForEach(viewModel.categoryOptions) { option in
                                Text(option.title).tag(option.id)
                            }
                        }
                    } else {
                        Text(L10n("statement.import.edit.income_category_hint"))
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                } header: {
                    Text(L10n("statement.import.edit.category_section"))
                }
                if let suggestion = SuggestedCategoryPresenter.display(for: viewModel.previewTransaction) {
                    Section {
                        SuggestedCategoryChip(display: suggestion)
                        if let source = viewModel.previewTransaction.categorizationSource {
                            Text(sourceLabel(source))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                        }
                    } header: {
                        Text(L10n("statement.import.edit.suggested_category_section"))
                    }
                }
                if let error = viewModel.error {
                    Section { Text(error).foregroundColor(AppColorTheme.negative) }
                }
            }
            .navigationTitle(L10n("statement.import.edit.transaction_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
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
        case .custom: return L10n("statement.import.source.custom")
        case .builtIn: return L10n("statement.import.source.builtin")
        case .manual: return L10n("statement.import.source.manual")
        }
    }
}

struct StatementImportSuccessView: View {
    let importedCount: Int
    let onDone: () -> Void

    private func importedHeadline(count: Int) -> String {
        count == 1
            ? L10n("statement.import.success_one")
            : String(format: L10n("statement.import.success_many"), count)
    }

    var body: some View {
        ZStack {
            AppColorTheme.background.ignoresSafeArea()
            VStack(spacing: AppSpacing.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(AppColorTheme.accent)
                Text(importedHeadline(count: importedCount))
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColorTheme.textPrimary)
                Text(L10n("statement.import.success_subtitle"))
                    .font(AppTypography.bodySecondary)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button(L10n("common.done"), action: onDone)
                    .buttonStyle(PrimaryCTAButtonStyle())
            }
            .padding(AppSpacing.m)
        }
    }
}

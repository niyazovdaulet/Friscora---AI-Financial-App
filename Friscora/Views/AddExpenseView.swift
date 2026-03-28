//
//  AddExpenseView.swift
//  Friscora
//
//  View for adding new expenses and incomes with modern UI/UX
//

import SwiftUI
import UIKit

enum AddType {
    case expense
    case income
}

struct AddExpenseView: View {
    @StateObject private var expenseViewModel = ExpenseViewModel()
    @StateObject private var incomeViewModel = IncomeViewModel()
    @StateObject private var customCategoryService = CustomCategoryService.shared
    @State private var selectedTabIndex: Int = 0
    @State private var selectedCustomCategoryId: UUID? = nil
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNoteFocused: Bool
    @State private var showSuccessMessage = false
    @State private var showEditCategoriesSheet = false
    @State private var amountDisplay: String = ""  // Formatted with commas for display
    @State private var amountFocusTrigger = 0
    @Environment(\.dismiss) private var dismiss
    
    // For navigation to Dashboard
    @Binding var selectedTab: Int
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        _selectedTab = selectedTab
    }
    
    // Computed property to sync selectedType with selectedTabIndex
    private var selectedType: AddType {
        selectedTabIndex == 0 ? .expense : .income
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Primary background color
                AppColorTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab selector with animation
                    typeSelectorSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    // Scrollable content using TabView
                    TabView(selection: $selectedTabIndex) {
                        // Expense tab
                        expenseContent
                            .dismissKeyboardOnBackgroundTap()
                            .tag(0)
                        
                        // Income tab
                        incomeContent
                            .dismissKeyboardOnBackgroundTap()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .animation(AppAnimation.formField, value: selectedTabIndex)
                .animation(AppAnimation.formField, value: isAmountFocused)
                .animation(AppAnimation.formField, value: isNoteFocused)
                .animation(AppAnimation.standard, value: canSave)
                
                // Sticky Save button at bottom
                if canSave {
                    VStack {
                        Spacer()
                        saveButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            .background(
                                LinearGradient(
                                    colors: [
                                        AppColorTheme.background.opacity(0.95),
                                        AppColorTheme.cardBackground.opacity(0.95)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .ignoresSafeArea(edges: .bottom)
                            )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
            }
            .navigationTitle(L10n("add_transaction.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        clearForm()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text(L10n("common.clear"))
                        }
                        .font(.subheadline)
                        .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showSuccessMessage) {
                SuccessSheetView(
                    type: selectedType,
                    onDismiss: {
                        selectedTab = 0
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sheet(isPresented: $showEditCategoriesSheet) {
                EditCategoriesView()
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .onAppear {
                applyLastUsedFromPersistence()
            }
        }
    }
    
    // MARK: - Type Selector
    private var typeSelectorSection: some View {
        HStack(spacing: 0) {
            // Expense button
            Button {
                HapticHelper.selection()
                withAnimation(AppAnimation.tabSwitch) {
                    selectedTabIndex = 0
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                    Text(L10n("add_transaction.expense"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedTabIndex == 0 ?
                    AppColorTheme.negativeGradient : nil
                )
                .foregroundColor(selectedTabIndex == 0 ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                .cornerRadius(16)
            }
            
            // Income button
            Button {
                HapticHelper.selection()
                withAnimation(AppAnimation.tabSwitch) {
                    selectedTabIndex = 1
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                    Text(L10n("add_transaction.income"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedTabIndex == 1 ?
                    AppColorTheme.positiveGradient : nil
                )
                .foregroundColor(selectedTabIndex == 1 ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                .cornerRadius(16)
            }
        }
        .background(AppColorTheme.elevatedBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Expense Content
    private var expenseContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                amountInputCard
                categorySelectorCard
                expenseDetailsDisclosure
                if canSave {
                    Spacer()
                        .frame(height: 80)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, canSave ? 0 : 20)
        }
    }
    
    // MARK: - Income Content
    private var incomeContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                amountInputCard
                incomeDetailsDisclosure
                if canSave {
                    Spacer()
                        .frame(height: 80)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, canSave ? 0 : 20)
        }
    }
    
    // MARK: - Amount Input Card (Smaller)
    private var amountInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n("common.amount"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                // Currency badge
                Text(UserProfileService.shared.profile.currency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedType == .expense ?
                        AppColorTheme.negativeGradient :
                        AppColorTheme.positiveGradient
                    )
                    .cornerRadius(10)
                    .shadow(color: selectedType == .expense ?
                            AppColorTheme.negative.opacity(0.3) :
                            AppColorTheme.positive.opacity(0.3),
                            radius: 6, x: 0, y: 3)
                
                // Custom numeric keyboard (period as decimal, comma for grouping)
                AmountInputWithCustomKeyboard(
                    amountDisplay: $amountDisplay,
                    placeholder: "0.00",
                    focusTrigger: amountFocusTrigger,
                    onFormatChange: { stripped in
                        if selectedType == .expense {
                            expenseViewModel.amount = stripped
                        } else {
                            incomeViewModel.amount = stripped
                        }
                    },
                    onFocusChange: { focused in
                        isAmountFocused = focused
                    }
                )
                .onChange(of: selectedTabIndex) { _, _ in
                    let raw = selectedType == .expense ? expenseViewModel.amount : incomeViewModel.amount
                    amountDisplay = CurrencyFormatter.formatAmountForDisplay(raw)
                }
                .onAppear {
                    let raw = selectedType == .expense ? expenseViewModel.amount : incomeViewModel.amount
                    amountDisplay = CurrencyFormatter.formatAmountForDisplay(raw)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 12, x: 0, y: 4)
        )
        .scaleEffect(isAmountFocused ? 1.01 : 1.0)
    }
    
    // MARK: - Category Selector Card (Smaller)
    private var categorySelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n("common.category"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColorTheme.textSecondary)
                
                Spacer()
                
                Button {
                    showEditCategoriesSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption)
                        Text(L10n("common.edit"))
                            .font(.caption)
                    }
                    .foregroundColor(AppColorTheme.accent)
                }
            }
            
            // Built-in categories
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    CompactCategoryButton(
                        category: category,
                        isSelected: expenseViewModel.selectedCategory == category && selectedCustomCategoryId == nil,
                        action: {
                            withAnimation(AppAnimation.standard) {
                                expenseViewModel.selectedCategory = category
                                selectedCustomCategoryId = nil
                            }
                            HapticHelper.selection()
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Custom categories
            if !customCategoryService.customCategories.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(customCategoryService.customCategories) { customCategory in
                        CompactCategoryButton(
                            customCategory: customCategory,
                            isSelected: selectedCustomCategoryId == customCategory.id,
                            action: {
                                withAnimation(AppAnimation.standard) {
                                    selectedCustomCategoryId = customCategory.id
                                    expenseViewModel.selectedCategory = .other
                                }
                                HapticHelper.selection()
                            }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColorTheme.cardBackground)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
        )
    }
    
    // MARK: - Details (date defaults to today; optional note)
    private var expenseDetailsDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n("common.date"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    datePickerRow(selection: $expenseViewModel.selectedDate, accent: AppColorTheme.negative)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n("add_transaction.note_optional"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    noteField(text: $expenseViewModel.note)
                }
            }
            .padding(.top, 8)
        } label: {
            Text(L10n("add_transaction.details"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.textSecondary)
        }
        .tint(AppColorTheme.accent)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColorTheme.cardBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
        )
    }

    private var incomeDetailsDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n("common.date"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    datePickerRow(selection: $incomeViewModel.selectedDate, accent: AppColorTheme.positive)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n("add_transaction.note_optional"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    noteField(text: $incomeViewModel.note)
                }
            }
            .padding(.top, 8)
        } label: {
            Text(L10n("add_transaction.details"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.textSecondary)
        }
        .tint(AppColorTheme.accent)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColorTheme.cardBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
        )
    }

    private func datePickerRow(selection: Binding<Date>, accent: Color) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(accent)
                .font(.body)
            AutoDismissDatePicker(selection: selection, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppColorTheme.elevatedBackground)
        .cornerRadius(12)
    }

    private func noteField(text: Binding<String>) -> some View {
        TextField(L10n("add_transaction.add_note_placeholder"), text: text, axis: .vertical)
            .focused($isNoteFocused)
            .lineLimit(3...6)
            .padding(12)
            .background(AppColorTheme.elevatedBackground)
            .cornerRadius(12)
    }
    
    // MARK: - Save Button (Sticky)
    private var saveButton: some View {
        Button {
            saveTransaction()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text(L10n("add_transaction.save_transaction"))
                    .fontWeight(.semibold)
                    .font(.headline)
            }
            .foregroundColor(AppColorTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                selectedType == .expense ?
                AppColorTheme.negativeGradient :
                AppColorTheme.positiveGradient
            )
            .cornerRadius(16)
            .shadow(
                color: selectedType == .expense ?
                AppColorTheme.negative.opacity(0.4) :
                AppColorTheme.positive.opacity(0.4),
                radius: 15, x: 0, y: 8
            )
        }
    }
    
    private var canSave: Bool {
        selectedType == .expense ? expenseViewModel.canSaveExpense : incomeViewModel.canSaveIncome
    }
    
    private func applyLastUsedFromPersistence() {
        let (cat, customId) = LastUsedExpenseCategory.load(customCategories: customCategoryService.customCategories)
        expenseViewModel.selectedCategory = cat
        selectedCustomCategoryId = customId
    }

    private func clearForm() {
        withAnimation(AppAnimation.standard) {
            expenseViewModel.amount = ""
            expenseViewModel.note = ""
            expenseViewModel.selectedDate = Date()
            incomeViewModel.amount = ""
            incomeViewModel.note = ""
            incomeViewModel.selectedDate = Date()
            amountDisplay = ""
            isAmountFocused = false
            isNoteFocused = false
        }
        applyLastUsedFromPersistence()
        HapticHelper.lightImpact()
    }

    private func saveTransaction() {
        HapticHelper.mediumImpact()

        if selectedType == .expense {
            LastUsedExpenseCategory.save(category: expenseViewModel.selectedCategory, customId: selectedCustomCategoryId)
            expenseViewModel.saveExpense(customCategoryId: selectedCustomCategoryId)
        } else {
            incomeViewModel.saveIncome()
        }

        clearFormAfterSuccessfulSave()
        showSuccessMessage = true
    }

    /// Clears amounts and resets dates to today; restores expense category from UserDefaults (`friscora.lastExpenseCategory`, `friscora.lastCustomCategoryId`).
    private func clearFormAfterSuccessfulSave() {
        withAnimation(AppAnimation.standard) {
            expenseViewModel.amount = ""
            expenseViewModel.note = ""
            expenseViewModel.selectedDate = Date()
            incomeViewModel.amount = ""
            incomeViewModel.note = ""
            incomeViewModel.selectedDate = Date()
            amountDisplay = ""
            isAmountFocused = false
            isNoteFocused = false
        }
        applyLastUsedFromPersistence()
    }
}

// MARK: - Compact Category Button
struct CompactCategoryButton: View {
    let category: ExpenseCategory?
    let customCategory: CustomCategory?
    let isSelected: Bool
    let action: () -> Void
    
    init(category: ExpenseCategory, isSelected: Bool, action: @escaping () -> Void) {
        self.category = category
        self.customCategory = nil
        self.isSelected = isSelected
        self.action = action
    }
    
    init(customCategory: CustomCategory, isSelected: Bool, action: @escaping () -> Void) {
        self.category = nil
        self.customCategory = customCategory
        self.isSelected = isSelected
        self.action = action
    }
    
    private var icon: String {
        customCategory?.icon ?? category?.icon ?? ""
    }
    
    private var name: String {
        customCategory?.name ?? category?.localizedName ?? ""
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 24))
                
                Text(name)
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? AppColorTheme.textPrimary : AppColorTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                isSelected ?
                AppColorTheme.negativeGradient :
                LinearGradient(
                    colors: [AppColorTheme.elevatedBackground, AppColorTheme.elevatedBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : AppColorTheme.grayDark, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? AppColorTheme.negative.opacity(0.3) : Color.clear,
                radius: 6, x: 0, y: 3
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Custom Category View
struct AddCustomCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customCategoryService = CustomCategoryService.shared
    @State private var categoryName: String = ""
    @State private var selectedEmoji: String = "📝"
    @FocusState private var isNameFocused: Bool
    
    let emojiOptions = ["📝", "🎯", "💡", "⭐", "🔥", "💎", "🎨", "🎵", "🏆", "🌟", "✨", "🎪", "🎭", "🎬", "📚", "🎮", "⚽", "🏀", "🎾", "🏊", "🚴", "🎲", "🎰", "💰", "💳", "🏥", "🎓", "🍕", "☕", "🚗"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n("category.name")) {
                    TextField(L10n("add_transaction.enter_category_name"), text: $categoryName)
                        .focused($isNameFocused)
                }
                
                Section(L10n("category.icon")) {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(Array(emojiOptions.enumerated()), id: \.offset) { index, emoji in
                                Button {
                                    selectedEmoji = emoji
                                    HapticHelper.selection()
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedEmoji == emoji ? AppColorTheme.accent.opacity(0.2) : AppColorTheme.elevatedBackground)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedEmoji == emoji ? AppColorTheme.accent : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(height: 300)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle(L10n("add_transaction.new_category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
                        saveCategory()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isNameFocused = true
                }
            }
        }
    }
    
    private func saveCategory() {
        let newCategory = CustomCategory(
            name: categoryName,
            icon: selectedEmoji
        )
        customCategoryService.addCategory(newCategory)
        HapticHelper.mediumImpact()
        dismiss()
    }
}

// MARK: - Success Sheet View
struct SuccessSheetView: View {
    let type: AddType
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var hasDismissed = false
    
    var body: some View {
        VStack(spacing: AppSpacing.m) {
            ZStack {
                Circle()
                    .fill((type == .expense ? AppColorTheme.negative : AppColorTheme.positive).opacity(0.2))
                    .frame(width: 88, height: 88)
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1.0 : 0)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(type == .expense ? AppColorTheme.negative : AppColorTheme.positive)
                    .scaleEffect(checkmarkScale)
            }
            .animation(AppAnimation.sheetPresent.delay(0.05), value: showContent)
            .animation(.spring(response: 0.45, dampingFraction: 0.65), value: checkmarkScale)
            
            Text(type == .expense ? L10n("add_transaction.expense_added") : L10n("add_transaction.income_added"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
                .opacity(showContent ? 1.0 : 0)
            
            Text(String(format: L10n("add_transaction.saved_success"), type == .expense ? L10n("activity.expense") : L10n("activity.income")))
                .font(AppTypography.caption)
                .foregroundColor(AppColorTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.l)
                .opacity(showContent ? 1.0 : 0)
            
            Button {
                HapticHelper.mediumImpact()
                guard !hasDismissed else { return }
                hasDismissed = true
                dismiss()
                onDismiss()
            } label: {
                Text(L10n("add_transaction.view_dashboard"))
            }
            .buttonStyle(PrimaryCTAButtonStyle())
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.s)
            .opacity(showContent ? 1.0 : 0)
        }
        .padding(.vertical, AppSpacing.l)
        .frame(maxHeight: .infinity)
        .onAppear {
            withAnimation(AppAnimation.sheetPresent.delay(0.1)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.15)) {
                checkmarkScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if showContent && !hasDismissed {
                    hasDismissed = true
                    dismiss()
                    onDismiss()
                }
            }
        }
    }
}

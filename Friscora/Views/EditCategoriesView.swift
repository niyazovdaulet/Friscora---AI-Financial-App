//
//  EditCategoriesView.swift
//  Friscora
//
//  Single ordered list: built-in + custom. Top 6 appear in Add Transaction.
//

import SwiftUI

private enum EditCategoryDisplayItem: Identifiable {
    case row(ExpenseCategoryOrderRow)
    case quickPickDivider

    var id: String {
        switch self {
        case .row(let r): return r.id
        case .quickPickDivider: return "_quick_pick_divider_"
        }
    }

    var isQuickPickDivider: Bool {
        if case .quickPickDivider = self { return true }
        return false
    }
}

struct EditCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customCategoryService = CustomCategoryService.shared
    @ObservedObject private var orderService = ExpenseCategoryOrderService.shared
    @State private var showAddCategorySheet = false
    @State private var editingCategory: CustomCategory? = nil

    private var rows: [ExpenseCategoryOrderRow] {
        orderService.orderedRows(customCategories: customCategoryService.customCategories)
    }

    /// Inserts a visual divider after the 6th category when more than six exist.
    private var displayItems: [EditCategoryDisplayItem] {
        var out: [EditCategoryDisplayItem] = []
        for (index, row) in rows.enumerated() {
            out.append(.row(row))
            if index == 5 && rows.count > 6 {
                out.append(.quickPickDivider)
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()

                List {
                    Section {
                        ForEach(displayItems) { item in
                            Group {
                                switch item {
                                case .row(let row):
                                    editCategoryRow(row)
                                case .quickPickDivider:
                                    quickPickDividerContent
                                }
                            }
                            .listRowInsets(
                                EdgeInsets(
                                    top: item.isQuickPickDivider ? 8 : 10,
                                    leading: 0,
                                    bottom: item.isQuickPickDivider ? 8 : 10,
                                    trailing: 0
                                )
                            )
                            .listRowBackground(categoryListRowBackground(for: item))
                            .listRowSeparator(.hidden)
                            .moveDisabled(item.isQuickPickDivider)
                        }
                        .onMove(perform: applyDisplayMove)
                    } header: {
                        Text(L10n("edit_categories.all_categories_header"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColorTheme.textPrimary)
                            .tracking(0.4)
                            .textCase(nil)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
                .padding(.horizontal, AppSpacing.m)
                .environment(\.editMode, .constant(.active))
            }
            .dismissKeyboardOnTap()
            .navigationTitle(L10n("edit_categories.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColorTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.done")) {
                        dismiss()
                    }
                    .foregroundColor(AppColorTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCategorySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(AppColorTheme.accent)
                }
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCustomCategoryView()
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sheet(item: $editingCategory) { category in
                EditCustomCategoryView(category: category)
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
        }
    }

    /// Built-in rows: darker inset surface. Custom rows: standard card (slightly brighter) so the two read at a glance.
    @ViewBuilder
    private func categoryListRowBackground(for item: EditCategoryDisplayItem) -> some View {
        if item.isQuickPickDivider {
            Color.clear
        } else if case .row(let row) = item {
            switch row {
            case .builtin:
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(AppColorTheme.layer3Elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
                    .padding(.vertical, 3)
            case .custom:
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(AppColorTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                    )
                    .padding(.vertical, 3)
            }
        } else {
            Color.clear
        }
    }

    private var quickPickDividerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(AppColorTheme.sapphire.opacity(0.5))
                    .frame(height: 1)
                Text(L10n("edit_categories.quick_pick_divider_badge"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColorTheme.textTertiary)
                    .tracking(0.6)
                Rectangle()
                    .fill(AppColorTheme.sapphire.opacity(0.5))
                    .frame(height: 1)
            }
            Text(L10n("edit_categories.quick_pick_divider_hint"))
                .font(AppTypography.caption)
                .foregroundColor(AppColorTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Insets inside the card: extra leading so the color chip clears the rounded edge (Revolut-style breathing room).
    private static let rowContentLeading: CGFloat = AppSpacing.m
    private static let rowContentTrailing: CGFloat = AppSpacing.s

    @ViewBuilder
    private func editCategoryRow(_ row: ExpenseCategoryOrderRow) -> some View {
        switch row {
        case .builtin(let category):
            HStack(alignment: .center, spacing: 14) {
                categoryColorDot(fill: AppColorTheme.color(for: category))
                Text(category.icon)
                    .font(.system(size: 26))
                    .frame(width: 32, alignment: .center)
                Text(category.localizedName)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.leading, Self.rowContentLeading)
            .padding(.trailing, Self.rowContentTrailing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

        case .custom(let category):
            Button {
                HapticHelper.selection()
                editingCategory = category
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    categoryColorDot(fill: Color(hex: category.colorHex))
                    Text(category.icon)
                        .font(.system(size: 26))
                        .frame(width: 32, alignment: .center)
                    Text(category.name)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(AppColorTheme.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.leading, Self.rowContentLeading)
                .padding(.trailing, Self.rowContentTrailing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(CategoryRowButtonStyle())
        }
    }

    private func categoryColorDot(fill: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.75))
            .shadow(color: fill.opacity(0.35), radius: 3, x: 0, y: 1)
    }

    private func applyDisplayMove(from source: IndexSet, to destination: Int) {
        var items = displayItems
        items.move(fromOffsets: source, toOffset: destination)
        let newRows = items.compactMap { item -> ExpenseCategoryOrderRow? in
            if case .row(let r) = item { return r }
            return nil
        }
        guard newRows.count == rows.count else { return }
        orderService.replaceAllRows(newRows)
    }
}

// MARK: - Row interaction (full-width tap, no chevron)

private struct CategoryRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct EditCustomCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customCategoryService = CustomCategoryService.shared
    let category: CustomCategory

    @State private var categoryName: String
    @State private var selectedEmoji: String
    @State private var selectedColorHex: String
    @FocusState private var isNameFocused: Bool
    @State private var showDeleteConfirmation = false

    init(category: CustomCategory) {
        self.category = category
        _categoryName = State(initialValue: category.name)
        _selectedEmoji = State(initialValue: category.icon)
        _selectedColorHex = State(initialValue: category.colorHex)
    }

    private var trimmedName: String {
        categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameIsDuplicate: Bool {
        CategoryNaming.isDuplicate(name: categoryName, excludingCustomCategoryId: category.id)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !nameIsDuplicate
    }

    private var duplicateHint: String? {
        nameIsDuplicate && !trimmedName.isEmpty ? L10n("category.name_taken") : nil
    }

    var body: some View {
        NavigationStack {
            CustomCategoryEditorContent(
                categoryName: $categoryName,
                selectedEmoji: $selectedEmoji,
                selectedColorHex: $selectedColorHex,
                focusName: $isNameFocused,
                lockedChartHexes: CategoryColorReservation.lockedChartHexes(excludingCustomCategoryId: category.id),
                lockedEmojis: CategoryIconReservation.lockedEmojis(excludingCustomCategoryId: category.id),
                nameDuplicateMessage: duplicateHint
            )
            .dismissKeyboardOnTap()
            .navigationTitle(L10n("edit_category.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColorTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(AppColorTheme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
                        saveCategory()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        canSave ? AppColorTheme.sapphire : AppColorTheme.textTertiary
                    )
                }

                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text(L10n("edit_category.delete"))
                            .foregroundColor(AppColorTheme.negative)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .alert(L10n("edit_category.delete_confirm_title"), isPresented: $showDeleteConfirmation) {
                Button(L10n("common.delete"), role: .destructive) {
                    deleteCategory()
                }
                Button(L10n("common.cancel"), role: .cancel) {}
            } message: {
                Text(L10n("edit_category.delete_confirm_message"))
            }
        }
    }

    private func saveCategory() {
        guard canSave else { return }
        let updatedCategory = CustomCategory(
            id: category.id,
            name: trimmedName,
            icon: selectedEmoji,
            colorHex: selectedColorHex,
            createdDate: category.createdDate
        )
        customCategoryService.updateCategory(updatedCategory)
        HapticHelper.mediumImpact()
        dismiss()
    }

    private func deleteCategory() {
        customCategoryService.deleteCategoryRevertingLinkedExpenses(category)
        HapticHelper.mediumImpact()
        dismiss()
    }
}

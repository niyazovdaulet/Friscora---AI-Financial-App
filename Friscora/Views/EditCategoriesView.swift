//
//  EditCategoriesView.swift
//  Friscora
//
//  View for editing and managing categories
//

import SwiftUI

struct EditCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customCategoryService = CustomCategoryService.shared
    @State private var showAddCategorySheet = false
    @State private var editingCategory: CustomCategory? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n("edit_categories.builtin_not_editable"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        HStack {
                            Text(category.icon)
                                .font(.title2)
                            Text(category.localizedName)
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text(L10n("edit_categories.builtin"))
                }
                
                Section {
                    if customCategoryService.customCategories.isEmpty {
                        EmptyStateView(
                            icon: "folder.badge.plus",
                            message: L10n("edit_categories.no_custom"),
                            actionTitle: L10n("add_transaction.new_category"),
                            action: { showAddCategorySheet = true },
                            compact: true
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: AppSpacing.m, leading: AppSpacing.m, bottom: AppSpacing.m, trailing: AppSpacing.m))
                    } else {
                        ForEach(customCategoryService.customCategories) { category in
                            HStack {
                                Text(category.icon)
                                    .font(.title2)
                                Text(category.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingCategory = category
                            }
                        }
                        .onDelete { indexSet in
                            deleteCategories(at: indexSet)
                        }
                    }
                } header: {
                    Text(L10n("edit_categories.custom"))
                } footer: {
                    Text(L10n("edit_categories.tap_to_edit"))
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle(L10n("edit_categories.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.done")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showAddCategorySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
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
    
    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let category = customCategoryService.customCategories[index]
            customCategoryService.deleteCategory(category)
        }
    }
}

struct EditCustomCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customCategoryService = CustomCategoryService.shared
    let category: CustomCategory
    
    @State private var categoryName: String
    @State private var selectedEmoji: String
    @FocusState private var isNameFocused: Bool
    
    let emojiOptions = ["📝", "🎯", "💡", "⭐", "🔥", "💎", "🎨", "🎵", "🏆", "🌟", "✨", "🎪", "🎭", "🎬", "📚", "🎮", "⚽", "🏀", "🎾", "🏊", "🚴", "🎲", "🎰", "💰", "💳", "🏥", "🎓", "🍕", "☕", "🚗"]
    
    init(category: CustomCategory) {
        self.category = category
        _categoryName = State(initialValue: category.name)
        _selectedEmoji = State(initialValue: category.icon)
    }
    
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
                                    impactFeedback(style: .light)
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedEmoji == emoji ? Color.blue : Color.clear, lineWidth: 2)
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
            .navigationTitle(L10n("edit_category.title"))
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
        let updatedCategory = CustomCategory(
            id: category.id,
            name: categoryName,
            icon: selectedEmoji,
            createdDate: category.createdDate
        )
        customCategoryService.updateCategory(updatedCategory)
        impactFeedback(style: .medium)
        dismiss()
    }
    
    private func impactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}


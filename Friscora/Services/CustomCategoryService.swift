//
//  CustomCategoryService.swift
//  Friscora
//
//  Service for managing custom categories
//

import Foundation
import Combine

class CustomCategoryService: ObservableObject {
    static let shared = CustomCategoryService()
    
    @Published var customCategories: [CustomCategory] = []
    
    private let categoriesKey = "saved_custom_categories"
    
    private init() {
        loadCategories()
        NotificationCenter.default.addObserver(self, selector: #selector(handleICloudSyncUpdate), name: .ICloudSyncDidUpdate, object: nil)
    }
    
    @objc private func handleICloudSyncUpdate() {
        loadCategories()
    }
    
    /// Load custom categories from UserDefaults
    func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([CustomCategory].self, from: data) {
            customCategories = decoded.sorted { $0.createdDate > $1.createdDate }
        }
    }
    
    /// Save custom categories to UserDefaults
    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(customCategories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    /// Add a new custom category
    func addCategory(_ category: CustomCategory) {
        customCategories.append(category)
        saveCategories()
    }
    
    /// Update a custom category
    func updateCategory(_ category: CustomCategory) {
        if let index = customCategories.firstIndex(where: { $0.id == category.id }) {
            customCategories[index] = category
            saveCategories()
        }
    }
    
    /// Delete a custom category
    func deleteCategory(_ category: CustomCategory) {
        customCategories.removeAll { $0.id == category.id }
        saveCategories()
    }
}


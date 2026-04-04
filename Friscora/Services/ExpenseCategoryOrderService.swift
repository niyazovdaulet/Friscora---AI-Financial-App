//
//  ExpenseCategoryOrderService.swift
//  Friscora
//
//  Persisted order of expense categories (built-in + custom). First 6 appear in Add Transaction.
//

import Combine
import Foundation
import SwiftUI

/// One row in the combined category list / quick picker.
enum ExpenseCategoryOrderRow: Identifiable {
    case builtin(ExpenseCategory)
    case custom(CustomCategory)

    var id: String {
        switch self {
        case .builtin(let c): return "builtin:\(c.rawValue)"
        case .custom(let c): return "custom:\(c.id.uuidString)"
        }
    }

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}

final class ExpenseCategoryOrderService: ObservableObject {
    static let shared = ExpenseCategoryOrderService()
    static let storageKey = "friscora.expenseCategoryOrder"

    @Published private(set) var orderedTokens: [String] = []

    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadFromDisk()
        CustomCategoryService.shared.$customCategories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] customs in
                self?.reconcile(customCategories: customs)
            }
            .store(in: &cancellables)
    }

    /// Rows for UI and quick picker (invalid tokens dropped).
    func orderedRows(customCategories: [CustomCategory]) -> [ExpenseCategoryOrderRow] {
        orderedTokens.compactMap { token in resolve(token: token, customCategories: customCategories) }
    }

    func quickPickerRows(customCategories: [CustomCategory]) -> [ExpenseCategoryOrderRow] {
        Array(orderedRows(customCategories: customCategories).prefix(6))
    }

    func move(fromOffsets: IndexSet, toOffset: Int, customCategories: [CustomCategory]) {
        var rows = orderedRows(customCategories: customCategories)
        rows.move(fromOffsets: fromOffsets, toOffset: toOffset)
        orderedTokens = rows.map { token(for: $0) }
        save()
    }

    /// Persists a full new order (e.g. after UI move that included a non-row divider).
    func replaceAllRows(_ rows: [ExpenseCategoryOrderRow]) {
        orderedTokens = rows.map { token(for: $0) }
        save()
    }

    func resetAfterDataErase(customCategories: [CustomCategory]) {
        orderedTokens = Self.defaultTokens(customCategories: customCategories)
        save()
    }

    // MARK: - Private

    private func token(for row: ExpenseCategoryOrderRow) -> String {
        switch row {
        case .builtin(let c): return "builtin:\(c.rawValue)"
        case .custom(let cat): return "custom:\(cat.id.uuidString)"
        }
    }

    private func resolve(token: String, customCategories: [CustomCategory]) -> ExpenseCategoryOrderRow? {
        if token.hasPrefix("builtin:") {
            let raw = String(token.dropFirst(8))
            guard let c = ExpenseCategory(rawValue: raw) else { return nil }
            return .builtin(c)
        }
        if token.hasPrefix("custom:") {
            let idStr = String(token.dropFirst(7))
            guard let id = UUID(uuidString: idStr),
                  let cat = customCategories.first(where: { $0.id == id }) else { return nil }
            return .custom(cat)
        }
        return nil
    }

    private static func defaultTokens(customCategories: [CustomCategory]) -> [String] {
        let built = ExpenseCategory.allCases.map { "builtin:\($0.rawValue)" }
        let customs = customCategories.sorted { $0.createdDate > $1.createdDate }.map { "custom:\($0.id.uuidString)" }
        return built + customs
    }

    private func reconcile(customCategories: [CustomCategory]) {
        if orderedTokens.isEmpty {
            orderedTokens = Self.defaultTokens(customCategories: customCategories)
            save()
            return
        }

        // Drop tokens that no longer resolve (deleted custom, etc.)
        orderedTokens = orderedTokens.filter { resolve(token: $0, customCategories: customCategories) != nil }

        let requiredBuiltins = Set(ExpenseCategory.allCases.map { "builtin:\($0.rawValue)" })
        let presentBuiltins = Set(orderedTokens.filter { $0.hasPrefix("builtin:") })
        if !requiredBuiltins.isSubset(of: presentBuiltins) {
            orderedTokens = Self.defaultTokens(customCategories: customCategories)
            save()
            return
        }

        // De-duplicate built-ins (keep first occurrence)
        var seenBuiltin = Set<String>()
        orderedTokens = orderedTokens.filter { token in
            guard token.hasPrefix("builtin:") else { return true }
            if seenBuiltin.contains(token) { return false }
            seenBuiltin.insert(token)
            return true
        }

        // Append new custom categories not yet in the list
        let existingCustomIds = Set(
            orderedTokens.compactMap { token -> UUID? in
                guard token.hasPrefix("custom:") else { return nil }
                return UUID(uuidString: String(token.dropFirst(7)))
            }
        )
        for c in customCategories.sorted(by: { $0.createdDate < $1.createdDate }) where !existingCustomIds.contains(c.id) {
            orderedTokens.append("custom:\(c.id.uuidString)")
        }

        save()
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            orderedTokens = decoded
        } else {
            orderedTokens = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(orderedTokens) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

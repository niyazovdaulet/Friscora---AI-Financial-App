//
//  ExpenseViewModel.swift
//  Friscora
//
//  ViewModel for expense management
//

import Foundation
import Combine

class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var amount: String = ""
    @Published var selectedCategory: ExpenseCategory = .food
    @Published var selectedDate: Date = Date()
    @Published var note: String = ""
    
    private let expenseService = ExpenseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        expenseService.$expenses
            .assign(to: &$expenses)
    }
    
    var canSaveExpense: Bool {
        !amount.isEmpty && (CurrencyFormatter.parsedAmount(from: amount) ?? 0) > 0
    }
    
    func saveExpense(customCategoryId: UUID? = nil) {
        guard let expenseAmount = CurrencyFormatter.parsedAmount(from: amount), expenseAmount > 0 else { return }
        
        let expense = Expense(
            amount: expenseAmount,
            category: selectedCategory,
            customCategoryId: customCategoryId,
            date: selectedDate,
            note: note.isEmpty ? nil : note
        )
        
        expenseService.addExpense(expense)
        resetForm()
    }
    
    func deleteExpense(_ expense: Expense) {
        expenseService.deleteExpense(expense)
    }
    
    private func resetForm() {
        amount = ""
        selectedDate = Date()
        note = ""
    }
}


//
//  IncomeViewModel.swift
//  Friscora
//
//  ViewModel for income management
//

import Foundation
import Combine

class IncomeViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var selectedDate: Date = Date()
    @Published var note: String = ""
    
    private let incomeService = IncomeService.shared
    
    var canSaveIncome: Bool {
        !amount.isEmpty && (CurrencyFormatter.parsedAmount(from: amount) ?? 0) > 0
    }
    
    func saveIncome() {
        guard let incomeAmount = CurrencyFormatter.parsedAmount(from: amount), incomeAmount > 0 else { return }
        
        let income = Income(
            amount: incomeAmount,
            date: selectedDate,
            note: note.isEmpty ? nil : note
        )
        
        incomeService.addIncome(income)
        resetForm()
    }
    
    private func resetForm() {
        amount = ""
        selectedDate = Date()
        note = ""
    }
}


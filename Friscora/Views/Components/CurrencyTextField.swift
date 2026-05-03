//
//  CurrencyTextField.swift
//  Friscora
//
//  Reusable currency input field
//

import SwiftUI

struct CurrencyTextField: View {
    let title: String
    /// ISO-style currency code shown beside the field (e.g. from profile).
    let currencyCode: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text(currencyCode)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)
                
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}


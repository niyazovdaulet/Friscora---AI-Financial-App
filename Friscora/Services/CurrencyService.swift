//
//  CurrencyService.swift
//  Friscora
//
//  Service for currency conversion using exchange rates API
//

import Foundation

struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
    let base: String
    let date: String
}

class CurrencyService {
    static let shared = CurrencyService()
    
    private let baseURL = "https://api.exchangerate-api.com/v4/latest/"
    private var cachedRates: [String: [String: Double]] = [:]
    private var cacheDate: Date?
    private let cacheValidityHours: TimeInterval = 24
    
    private init() {}
    
    /// Get exchange rate from one currency to another
    func getExchangeRate(from: String, to: String) async throws -> Double {
        // Same currency
        if from == to {
            return 1.0
        }
        
        // Check cache first
        if let cached = getCachedRate(from: from, to: to) {
            return cached
        }
        
        // Fetch from API
        guard let url = URL(string: "\(baseURL)\(from)") else {
            throw CurrencyError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
        
        // Cache the rates
        cachedRates[from] = response.rates
        cacheDate = Date()
        
        // Return the rate
        guard let rate = response.rates[to] else {
            throw CurrencyError.rateNotFound
        }
        
        return rate
    }
    
    /// Convert amount from one currency to another
    func convert(amount: Double, from: String, to: String) async throws -> Double {
        let rate = try await getExchangeRate(from: from, to: to)
        return amount * rate
    }
    
    /// Get cached rate if available and valid
    private func getCachedRate(from: String, to: String) -> Double? {
        guard let cacheDate = cacheDate,
              Date().timeIntervalSince(cacheDate) < cacheValidityHours * 3600,
              let rates = cachedRates[from],
              let rate = rates[to] else {
            return nil
        }
        return rate
    }
}

enum CurrencyError: Error {
    case invalidURL
    case rateNotFound
    case networkError
}


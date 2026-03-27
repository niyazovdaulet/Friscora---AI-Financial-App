//
//  CurrencyFormatter.swift
//  Friscora
//
//  Helper for formatting currency values (comma as thousands separator)
//

import Foundation

// MARK: - Amount components (major / minor / currency)

/// Split amount for typographic hierarchy: major (12,778), minor (.54), currency (PLN).
/// Decimals don't control layout; compact format used for very large numbers.
struct AmountComponents {
    let major: String   // Integer part with grouping, e.g. "12,778" or "-12,778"
    let minor: String   // Decimal part including dot, e.g. ".54" or ".00"
    let currency: String
}

struct CurrencyFormatter {
    /// Uses comma as grouping separator and period for decimals (e.g. 2,076,008 or 22.5 PLN).
    static func format(_ amount: Double, currencyCode: String) -> String {
        let formatter = decimalFormatter(maxFractionDigits: 2)
        let formattedAmount = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(formattedAmount) \(currencyCode)"
    }
    
    /// Returns split components for hero/secondary amount UI. Use full format for &lt; 1M; for ≥1M/≥1B use compact string via formatCompact.
    static func components(_ amount: Double, currencyCode: String) -> AmountComponents {
        let absAmount = abs(amount)
        if absAmount >= 1_000_000_000 {
            return AmountComponents(major: formatCompact(amount, currencyCode: currencyCode), minor: "", currency: "")
        }
        if absAmount >= 1_000_000 {
            return AmountComponents(major: formatCompact(amount, currencyCode: currencyCode), minor: "", currency: "")
        }
        let formatter = decimalFormatter(maxFractionDigits: 2)
        let full = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        var major = full
        var minor = ".00"
        if let dotIndex = full.firstIndex(of: ".") {
            major = String(full[..<dotIndex])
            minor = String(full[dotIndex...])
        }
        return AmountComponents(major: major, minor: minor, currency: currencyCode)
    }

    /// Compact format for tight spaces: 13_279_479 → "13.3M KZT", 395_101 → "395.1k KZT". Use in summary cards so large amounts fit.
    static func formatCompact(_ amount: Double, currencyCode: String) -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-" : ""
        if absAmount >= 1_000_000 {
            return String(format: "%@%.1fM %@", sign, absAmount / 1_000_000, currencyCode)
        }
        if absAmount >= 1_000 {
            let k = absAmount / 1_000
            let format = k == floor(k) ? "%@%.0fk %@" : "%@%.1fk %@"
            return String(format: format, sign, k, currencyCode)
        }
        return format(amount, currencyCode: currencyCode)
    }
    
    /// Chart axis compact format: K as integer (501K), M with one decimal (1.4M). Examples: 501_239→501K, 1_432_238→1.4M.
    static func formatCompactChartAxis(_ amount: Double, currencyCode: String) -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-" : ""
        if absAmount >= 1_000_000 {
            return String(format: "%@%.1fM %@", sign, absAmount / 1_000_000, currencyCode)
        }
        if absAmount >= 1_000 {
            let k = absAmount / 1_000
            return String(format: "%@%.0fK %@", sign, k, currencyCode)
        }
        return format(amount, currencyCode: currencyCode)
    }
    
    /// Uses comma as grouping and period for decimals; replaces symbol with currency code.
    static func formatWithSymbol(_ amount: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        var formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        if let symbol = formatter.currencySymbol {
            formatted = formatted.replacingOccurrences(of: symbol, with: currencyCode)
        }
        return formatted
    }
    
    /// Format a raw digit string for display in amount text fields.
    /// Comma = thousands grouping, period = decimal (e.g. "5000.99" → "5,000.99").
    /// Preserves a trailing period ("4.") and decimal parts with leading/trailing zeros ("4.0", "4.01") so the user can type e.g. 4.01.
    static func formatAmountForDisplay(_ rawDigits: String) -> String {
        let stripped = stripAmountFormatting(rawDigits)
        if stripped.isEmpty { return "" }
        guard let value = Double(stripped) else { return rawDigits }
        let hasDecimal = stripped.contains(".")
        let formatter = decimalFormatter(maxFractionDigits: hasDecimal ? 2 : 0)
        if stripped.hasSuffix(".") {
            let formatted = formatter.string(from: NSNumber(value: value)) ?? stripped
            return formatted + "."
        }
        if hasDecimal, let dotIndex = stripped.firstIndex(of: ".") {
            let beforeDot = String(stripped[..<dotIndex])
            let afterDot = String(stripped[stripped.index(after: dotIndex)...])
            let decimalDigits = String(afterDot.prefix(2))
            let intValue = Double(beforeDot) ?? value
            let formattedInt = formatter.string(from: NSNumber(value: intValue)) ?? beforeDot
            return formattedInt + "." + decimalDigits
        }
        return formatter.string(from: NSNumber(value: value)) ?? rawDigits
    }
    
    /// Strip formatting: comma = grouping (removed), period = decimal (kept at most one).
    /// e.g. "1,500.99" → "1500.99", "5,000" → "5000".
    static func stripAmountFormatting(_ input: String) -> String {
        let noCommas = input.replacingOccurrences(of: ",", with: "")
        var result = ""
        var seenDot = false
        for c in noCommas {
            if c == "." {
                if !seenDot { result.append("."); seenDot = true }
            } else if c.isNumber {
                result.append(c)
            }
        }
        return result
    }
    
    /// Parse amount from string (comma = grouping, period = decimal); returns nil if invalid.
    static func parsedAmount(from string: String) -> Double? {
        let raw = stripAmountFormatting(string)
        guard !raw.isEmpty else { return nil }
        return Double(raw).map { roundToTwoDecimals($0) }
    }
    
    /// Rounds to 2 decimal places to avoid floating‑point drift (e.g. 14.999… → 15.0).
    static func roundToTwoDecimals(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }
    
    private static func decimalFormatter(maxFractionDigits: Int = 0) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}


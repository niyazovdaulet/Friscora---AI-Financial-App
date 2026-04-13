import Foundation

struct TransactionTextNormalizer {
    func normalize(_ text: String) -> String {
        let canonical = text.precomposedStringWithCanonicalMapping.lowercased()
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(canonical.unicodeScalars.count)

        for scalar in canonical.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                scalars.append(scalar)
            } else {
                scalars.append(" ")
            }
        }

        let cleaned = String(String.UnicodeScalarView(scalars))
        return cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extra cleanup for bank statement descriptors before keyword matching.
    /// Removes card masks and FX fragments while preserving merchant core tokens.
    func normalizeForCategorization(_ text: String) -> String {
        var value = normalize(text)
        let patterns = [
            #"\b\d+\s*[a-z]{3}\s*=\s*[\d\.,]+\s*[a-z]{3}\b"#, // FX fragments like "1 usd=3.85 pln"
            #"\b\d{2,}\*{2,}\d{2,}\b"#,                       // card masks like "1234****5678"
            #"\*{2,}"#,                                        // generic mask tails
            #"\b(pln|usd|eur|gbp|rub|kzt)\b(?:\s+\1\b)+"#      // duplicated currency tokens
        ]

        for pattern in patterns {
            value = value.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }

        return value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

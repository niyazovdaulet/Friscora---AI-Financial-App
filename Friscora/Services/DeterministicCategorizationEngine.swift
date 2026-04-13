import Foundation

struct DeterministicCategoryRule: Hashable {
    let id: String
    let targetBuiltInCategory: ExpenseCategory
    let confidence: Double
    let reason: String
    let keywords: [String]
}

struct DeterministicRuleCatalog {
    /// Safe rule-maintenance guidance:
    /// - Keep keywords merchant-specific and deterministic.
    /// - Prefer adding narrowly-scoped rules over broad tokens.
    /// - Keep fee/transfer-like rules conservative to avoid false positives.
    /// - Add tests for every new noisy descriptor before shipping.
    static let seededRules: [DeterministicCategoryRule] = [
        DeterministicCategoryRule(
            id: "food-grocery-core",
            targetBuiltInCategory: .food,
            confidence: 0.92,
            reason: "Grocery or food merchant keyword matched.",
            keywords: ["ZABKA", "LIDL", "BIEDRONKA", "CARREFOUR", "BAR MLECZNY", "MCDONALDS", "KEBAB", "SIMIT HOUSE"]
        ),
        DeterministicCategoryRule(
            id: "transport-rides-fuel",
            targetBuiltInCategory: .transport,
            confidence: 0.90,
            reason: "Ride, fuel, or transit-like keyword matched.",
            keywords: ["UBER", "BOLT", "ORLEN", "CIRCLE K", "MERA", "MPSA", "BILET", "TICKET"]
        ),
        DeterministicCategoryRule(
            id: "subscriptions-billing",
            targetBuiltInCategory: .subscriptions,
            confidence: 0.90,
            reason: "Recurring billing/subscription descriptor matched.",
            keywords: ["APPLE COM BILL", "APPLECOM BILL", "T MOBILE", "TMOBILE", "CURSOR", "AI POWERED IDE"]
        ),
        DeterministicCategoryRule(
            id: "entertainment-events-gaming",
            targetBuiltInCategory: .entertainment,
            confidence: 0.88,
            reason: "Entertainment venue, ticketing, or gaming keyword matched.",
            keywords: ["ARENA KLUB", "TICKETMASTER", "GAMING CLUB", "GAME CLUB"]
        ),
        DeterministicCategoryRule(
            id: "fees-provision",
            targetBuiltInCategory: .other,
            confidence: 0.86,
            reason: "Fee/provision descriptor matched.",
            keywords: ["OPLATA", "PROWIZJA", "COMMISSION", "FEE"]
        ),
        DeterministicCategoryRule(
            id: "transfer-phone-safe-fallback",
            targetBuiltInCategory: .other,
            confidence: 0.45,
            reason: "Transfer-to-phone descriptor routed to safe fallback category.",
            keywords: ["TRANSFER TO THE PHONE", "TRANSFER TO PHONE", "BLIK TRANSFER TO MOBILE"]
        )
    ]
}

struct DeterministicCategorizationResolver {
    private let rules: [DeterministicCategoryRule]
    private let normalizer: TransactionTextNormalizer
    private let learningStore: MerchantLearningStoreProviding

    init(
        rules: [DeterministicCategoryRule] = DeterministicRuleCatalog.seededRules,
        normalizer: TransactionTextNormalizer = TransactionTextNormalizer(),
        learningStore: MerchantLearningStoreProviding = LearnedMerchantStore.shared
    ) {
        self.rules = rules
        self.normalizer = normalizer
        self.learningStore = learningStore
    }

    func resolve(
        transactionDescription: String,
        snapshot: [CategoryReference]
    ) -> CategorySuggestion {
        let normalized = normalizedForMatching(transactionDescription)
        guard !normalized.isEmpty else {
            return makeSuggestion(
                category: fallbackCategory(in: snapshot),
                confidence: CategorizationThresholds.fallbackConfidence,
                reason: "Description empty or invalid after normalization. Routed to safe fallback."
            )
        }

        if let learnedCategory = learningStore.learnedCategoryReference(
            for: transactionDescription,
            snapshot: snapshot
        ) {
            return makeSuggestion(
                category: learnedCategory,
                confidence: 1.0,
                reason: "Matched your previous manual correction for this merchant."
            )
        }

        if let matched = bestMatchingRule(in: normalized),
           let category = snapshot.first(where: { $0.builtInCategory == matched.targetBuiltInCategory }) {
            return makeSuggestion(
                category: category,
                confidence: matched.confidence,
                reason: matched.reason
            )
        }

        if let directNameMatch = bestCategoryNameMatch(in: normalized, snapshot: snapshot) {
            return makeSuggestion(
                category: directNameMatch.category,
                confidence: directNameMatch.confidence,
                reason: directNameMatch.reason
            )
        }

        let fallback = fallbackCategory(in: snapshot)
        return makeSuggestion(
            category: fallback,
            confidence: CategorizationThresholds.fallbackConfidence,
            reason: "No deterministic rule matched. Routed to safe fallback."
        )
    }

    private func bestMatchingRule(in normalized: String) -> DeterministicCategoryRule? {
        rules
            .filter { rule in
                rule.keywords.contains(where: { normalized.contains(normalizedForMatching($0)) })
            }
            .max { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.keywords.count < rhs.keywords.count
                }
                return lhs.confidence < rhs.confidence
            }
    }

    private func bestCategoryNameMatch(
        in normalized: String,
        snapshot: [CategoryReference]
    ) -> CategorySuggestion? {
        let matched = snapshot.compactMap { category -> (CategoryReference, Double)? in
            let categoryName = normalizedForMatching(category.displayName)
            guard !categoryName.isEmpty, normalized.contains(categoryName) else { return nil }
            let confidence = category.source == .custom ? 0.70 : 0.62
            return (category, confidence)
        }
        .max { lhs, rhs in lhs.1 < rhs.1 }

        guard let (category, confidence) = matched else { return nil }
        return CategorySuggestion(
            category: category,
            confidence: confidence,
            reason: "Matched active category name in transaction description."
        )
    }

    private func fallbackCategory(in snapshot: [CategoryReference]) -> CategoryReference {
        if let other = snapshot.first(where: { $0.builtInCategory == .other }) {
            return other
        }
        return snapshot.first ?? CategoryReference(builtIn: .other)
    }

    private func normalizedForMatching(_ text: String) -> String {
        let cleaned = normalizer.normalizeForCategorization(text)
        return cleaned
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }

    private func makeSuggestion(
        category: CategoryReference,
        confidence: Double,
        reason: String
    ) -> CategorySuggestion {
        let clamped = min(max(confidence, 0), 1)
        let safeReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Categorization matched using deterministic policy."
            : reason
        return CategorySuggestion(category: category, confidence: clamped, reason: safeReason)
    }
}

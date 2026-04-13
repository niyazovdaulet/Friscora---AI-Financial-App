import Foundation

struct LearnedCategoryReference: Codable, Hashable {
    var builtInCategory: ExpenseCategory?
    var customCategoryID: UUID?
}

struct LearnedMerchantMapping: Codable, Hashable {
    var merchantFingerprint: String
    var learnedCategory: LearnedCategoryReference
    var updatedAt: Date
    var hitCount: Int
}

private struct LearnedMerchantStoreEnvelope: Codable {
    var schemaVersion: Int
    var mappings: [LearnedMerchantMapping]
}

protocol MerchantLearningStoreProviding {
    func learnedCategoryReference(
        for transactionDescription: String,
        snapshot: [CategoryReference]
    ) -> CategoryReference?

    func saveManualOverride(
        transactionDescription: String,
        builtInCategory: ExpenseCategory?,
        customCategoryID: UUID?
    )
}

final class LearnedMerchantStore: MerchantLearningStoreProviding {
    static let shared = LearnedMerchantStore()
    private let schemaVersion = 1
    private let storageKey: String
    private let defaults: UserDefaults
    private let normalizer = TransactionTextNormalizer()

    init(storageKey: String = "statement_import_learned_merchants_v1", defaults: UserDefaults = .standard) {
        self.storageKey = storageKey
        self.defaults = defaults
    }

    func learnedCategoryReference(
        for transactionDescription: String,
        snapshot: [CategoryReference]
    ) -> CategoryReference? {
        let fingerprint = merchantFingerprint(from: transactionDescription)
        guard !fingerprint.isEmpty else { return nil }
        guard let mapping = loadMappings().first(where: { $0.merchantFingerprint == fingerprint }) else {
            return nil
        }
        if let customID = mapping.learnedCategory.customCategoryID {
            return snapshot.first(where: { $0.customCategoryID == customID })
        }
        if let builtIn = mapping.learnedCategory.builtInCategory {
            return snapshot.first(where: { $0.builtInCategory == builtIn })
        }
        return nil
    }

    func saveManualOverride(
        transactionDescription: String,
        builtInCategory: ExpenseCategory?,
        customCategoryID: UUID?
    ) {
        let fingerprint = merchantFingerprint(from: transactionDescription)
        guard !fingerprint.isEmpty else { return }
        guard builtInCategory != nil || customCategoryID != nil else { return }

        var mappings = loadMappings()
        if let index = mappings.firstIndex(where: { $0.merchantFingerprint == fingerprint }) {
            mappings[index].learnedCategory = LearnedCategoryReference(
                builtInCategory: builtInCategory,
                customCategoryID: customCategoryID
            )
            mappings[index].updatedAt = Date()
            mappings[index].hitCount += 1
        } else {
            mappings.append(
                LearnedMerchantMapping(
                    merchantFingerprint: fingerprint,
                    learnedCategory: LearnedCategoryReference(
                        builtInCategory: builtInCategory,
                        customCategoryID: customCategoryID
                    ),
                    updatedAt: Date(),
                    hitCount: 1
                )
            )
        }
        saveMappings(mappings)
    }

    func loadMappings() -> [LearnedMerchantMapping] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        guard let decoded = try? JSONDecoder().decode(LearnedMerchantStoreEnvelope.self, from: data) else {
            return []
        }
        guard decoded.schemaVersion == schemaVersion else { return [] }
        return decoded.mappings
    }

    func clearAll() {
        defaults.removeObject(forKey: storageKey)
    }

    private func saveMappings(_ mappings: [LearnedMerchantMapping]) {
        let envelope = LearnedMerchantStoreEnvelope(schemaVersion: schemaVersion, mappings: mappings)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func merchantFingerprint(from description: String) -> String {
        let cleaned = normalizer.normalizeForCategorization(description)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        let tokens = cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.allSatisfy(\.isNumber) }

        return tokens.prefix(6).joined(separator: " ")
    }
}

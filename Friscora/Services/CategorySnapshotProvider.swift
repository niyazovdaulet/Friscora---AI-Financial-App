import Foundation

protocol CategorySnapshotProviding {
    func activeCategorySnapshot() -> [CategoryReference]
}

struct CategorySnapshotProvider: CategorySnapshotProviding {
    private let customCategoryService: CustomCategoryService

    init(customCategoryService: CustomCategoryService = .shared) {
        self.customCategoryService = customCategoryService
    }

    func activeCategorySnapshot() -> [CategoryReference] {
        let builtIn = ExpenseCategory.allCases.map { CategoryReference(builtIn: $0) }
        let custom = customCategoryService.customCategories.map { CategoryReference(custom: $0) }
        return builtIn + custom
    }
}

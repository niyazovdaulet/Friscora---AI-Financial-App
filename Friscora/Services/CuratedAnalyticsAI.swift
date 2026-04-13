import Foundation

enum AnalyticsAIIntent: String, CaseIterable, Identifiable {
    case biggestDriver
    case concentrationRisk
    case incomeVsOutflows
    case savingsRateGoals
    case burnPace
    case categoryDrill
    case topThree
    case smallPurchases
    case momComparison
    case goalContext
    case singleGoalEmergency
    case whatIfCut
    case whereMoneyGoes
    case trustProvenance
    case savingsVsExpenses
    case leftover
    case biggestChangeMoM
    case zeroData
    case totalIncomeFact
    case totalExpensesFact
    
    var id: String { rawValue }
    
    func matches(normalizedQuestion: String) -> Bool {
        switch self {
        case .biggestDriver:
            return containsAny(normalizedQuestion, ["drove my spending", "biggest driver", "najwiekszy czynnik", "co napedza wydatki", "co napedzilo wydatki"])
        case .concentrationRisk:
            return containsAny(normalizedQuestion, ["dependent on one category", "one category", "single category", "jednej kategorii", "jedna kategoria", "zalezn"])
        case .incomeVsOutflows:
            return containsAny(normalizedQuestion, ["living within my means", "income vs", "wydatki vs dochod", "mieszcze sie w dochodach", "na minusie"])
        case .savingsRateGoals:
            return containsAny(normalizedQuestion, ["savings rate", "stopa oszczedzania", "jak duzo oszczedzam", "jaki procent oszczedzam"])
        case .burnPace:
            return containsAny(normalizedQuestion, ["at this pace", "overspend", "burn pace", "tym tempie", "przekrocze", "czy wydam za duzo"])
        case .categoryDrill:
            return containsAny(normalizedQuestion, ["how much did i spend on", "ile wydalem na", "ile wydalam na", "wydatki na", "spend on"])
        case .topThree:
            return containsAny(normalizedQuestion, ["top 3", "top three", "top categories", "top kategorie", "3 kategorie"])
        case .smallPurchases:
            return containsAny(normalizedQuestion, ["small expenses", "small purchases", "male wydatki", "drobne wydatki"])
        case .momComparison:
            return containsAny(normalizedQuestion, ["compare to last month", "month compare", "mom", "porown", "w porownaniu do zeszlego", "vs poprzedni"])
        case .goalContext:
            return containsAny(normalizedQuestion, ["goals progressing", "savings goals", "postep cel", "jak ida cele", "cele oszczed"])
        case .singleGoalEmergency:
            return containsAny(normalizedQuestion, ["emergency fund", "fundusz awaryjny", "poduszka finansowa"])
        case .whatIfCut:
            return containsAny(normalizedQuestion, ["if i cut", "what if i cut", "jesli ogranicze", "co jesli ogranicze", "obetne", "zmniejsze o"])
        case .whereMoneyGoes:
            return containsAny(normalizedQuestion, ["where is my money going", "where money goes", "gdzie ida moje pieniadze", "na co wydaje"])
        case .trustProvenance:
            return containsAny(normalizedQuestion, ["where does this answer come from", "source of this answer", "skad ta odpowiedz", "na podstawie czego"])
        case .savingsVsExpenses:
            return containsAny(normalizedQuestion, ["expenses vs savings", "went to expenses vs savings", "wydatki vs oszczednosci", "ile na wydatki a ile na oszczednosci"])
        case .leftover:
            return containsAny(normalizedQuestion, ["how much money is left", "left after spending", "ile zostalo", "ile mi zostaje"])
        case .biggestChangeMoM:
            return containsAny(normalizedQuestion, ["changed the most since last month", "biggest change", "najwieksza zmiana", "co zmienilo sie najbardziej"])
        case .zeroData:
            return containsAny(normalizedQuestion, ["analytics empty", "why empty", "brak danych", "dlaczego pusto"])
        case .totalIncomeFact:
            return containsAny(normalizedQuestion, ["total income", "my income this month", "laczny przychod", "suma przychodow"])
        case .totalExpensesFact:
            return containsAny(normalizedQuestion, ["total expenses", "my expenses this month", "laczne wydatki", "suma wydatkow"])
        }
    }
    
    func answer(context: RichAnalyticsContext) -> String {
        switch self {
        case .biggestDriver:
            guard let top = context.categorySpending.first, context.monthlyExpenses > 0 else {
                return L10n("ai.answer.biggest_driver.empty")
            }
            let share = Int(round((top.amount / context.monthlyExpenses) * 100))
            return String(format: L10n("ai.answer.biggest_driver"), top.displayName, money(top.amount, context.currencyCode), share, actionLine(for: context.primaryGoal))
        case .concentrationRisk:
            guard let top = context.categorySpending.first, context.monthlyExpenses > 0 else {
                return L10n("ai.answer.concentration.empty")
            }
            let share = Int(round((top.amount / context.monthlyExpenses) * 100))
            let risk = share >= 40 ? L10n("ai.answer.concentration.risky") : L10n("ai.answer.concentration.ok")
            return String(format: L10n("ai.answer.concentration"), top.displayName, share, risk)
        case .incomeVsOutflows:
            let delta = context.monthlyIncome - context.monthlyExpenses
            return String(format: L10n("ai.answer.income_vs_outflows"), money(context.monthlyIncome, context.currencyCode), money(context.monthlyExpenses, context.currencyCode), signedMoney(delta, context.currencyCode))
        case .savingsRateGoals:
            guard context.monthlyIncome > 0 else { return L10n("ai.answer.savings_rate.no_income") }
            let pct = Int(round((context.goalAllocationsThisMonth / context.monthlyIncome) * 100))
            return String(format: L10n("ai.answer.savings_rate"), pct, money(context.goalAllocationsThisMonth, context.currencyCode), money(context.monthlyIncome, context.currencyCode))
        case .burnPace:
            return burnPaceAnswer(context)
        case .categoryDrill:
            return categoryDrillAnswer(context)
        case .topThree:
            let top = Array(context.categorySpending.prefix(3))
            guard !top.isEmpty, context.monthlyExpenses > 0 else { return L10n("ai.answer.top_three.empty") }
            let list = top.map { item in
                let share = Int(round((item.amount / context.monthlyExpenses) * 100))
                return "\(item.displayName): \(money(item.amount, context.currencyCode)) (\(share)%)"
            }.joined(separator: ", ")
            return String(format: L10n("ai.answer.top_three"), list)
        case .smallPurchases:
            let threshold = 50.0
            let small = context.expensesThisMonth.filter { $0.amount < threshold }
            let sum = small.reduce(0) { $0 + $1.amount }
            let share = context.monthlyExpenses > 0 ? Int(round((sum / context.monthlyExpenses) * 100)) : 0
            return String(format: L10n("ai.answer.small_purchases"), Int(threshold), small.count, money(sum, context.currencyCode), share)
        case .momComparison:
            let incomeDelta = context.monthlyIncome - context.previousMonthIncome
            let expensesDelta = context.monthlyExpenses - context.previousMonthExpenses
            let incomePct = percentChange(current: context.monthlyIncome, previous: context.previousMonthIncome)
            let expensesPct = percentChange(current: context.monthlyExpenses, previous: context.previousMonthExpenses)
            return String(format: L10n("ai.answer.mom_comparison"), signedMoney(incomeDelta, context.currencyCode), signedPercent(incomePct), signedMoney(expensesDelta, context.currencyCode), signedPercent(expensesPct))
        case .goalContext:
            let goals = Array(context.activeGoals.prefix(3))
            guard !goals.isEmpty else { return L10n("ai.answer.goals.empty") }
            let summary = goals.map { goal in
                let progress = Int(round(goal.progress * 100))
                let remaining = max(0, goal.targetAmount - goal.currentAmount)
                return "\(goal.title): \(progress)% (\(money(remaining, context.currencyCode)) \(L10n("ai.answer.goals.remaining")))"
            }.joined(separator: ", ")
            return String(format: L10n("ai.answer.goals"), summary)
        case .singleGoalEmergency:
            let target = findEmergencyGoal(in: context.activeGoals)
            guard let goal = target else { return L10n("ai.answer.single_goal.empty") }
            let remaining = max(0, goal.targetAmount - goal.currentAmount)
            let progress = Int(round(goal.progress * 100))
            return String(format: L10n("ai.answer.single_goal"), goal.title, progress, money(remaining, context.currencyCode))
        case .whatIfCut:
            return whatIfCutAnswer(context)
        case .whereMoneyGoes:
            let top = Array(context.categorySpending.prefix(3))
            guard !top.isEmpty, context.monthlyExpenses > 0 else { return L10n("ai.answer.where_money_goes.empty") }
            let narrative = top.map { item in
                let pct = Int(round((item.amount / context.monthlyExpenses) * 100))
                return "\(item.displayName) \(pct)%"
            }.joined(separator: ", ")
            return String(format: L10n("ai.answer.where_money_goes"), narrative)
        case .trustProvenance:
            return String(format: L10n("ai.answer.trust"), context.referenceMonthDisplayString)
        case .savingsVsExpenses:
            return String(format: L10n("ai.answer.savings_vs_expenses"), money(context.monthlyExpenses, context.currencyCode), money(context.goalAllocationsThisMonth, context.currencyCode), money(context.monthlyIncome, context.currencyCode))
        case .leftover:
            let leftover = context.monthlyIncome - context.monthlyExpenses - context.goalAllocationsThisMonth
            return String(format: L10n("ai.answer.leftover"), signedMoney(leftover, context.currencyCode))
        case .biggestChangeMoM:
            return biggestChangeAnswer(context)
        case .zeroData:
            if context.monthlyIncome == 0 && context.monthlyExpenses == 0 {
                return String(format: L10n("ai.answer.zero_data"), context.referenceMonthDisplayString)
            }
            return L10n("ai.answer.zero_data.not_empty")
        case .totalIncomeFact:
            return String(format: L10n("ai.answer.total_income"), money(context.monthlyIncome, context.currencyCode))
        case .totalExpensesFact:
            return String(format: L10n("ai.answer.total_expenses"), money(context.monthlyExpenses, context.currencyCode))
        }
    }
}

enum CuratedAnalyticsAI {
    static func replyIfMatched(context: RichAnalyticsContext) -> String? {
        let question = normalize(context.userQuestion)
        guard !question.isEmpty else { return nil }
        
        for intent in AnalyticsAIIntent.allCases where intent.matches(normalizedQuestion: question) {
            return intent.answer(context: context)
        }
        return nil
    }
}

private func containsAny(_ text: String, _ candidates: [String]) -> Bool {
    candidates.contains(where: { text.contains(normalize($0)) })
}

private func normalize(_ text: String) -> String {
    text.lowercased()
        .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: LocalizationManager.shared.currentLocale)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func money(_ value: Double, _ currencyCode: String) -> String {
    CurrencyFormatter.format(value, currencyCode: currencyCode)
}

private func signedMoney(_ value: Double, _ currencyCode: String) -> String {
    let prefix = value >= 0 ? "+" : "-"
    return "\(prefix)\(CurrencyFormatter.format(abs(value), currencyCode: currencyCode))"
}

private func percentChange(current: Double, previous: Double) -> Int {
    guard previous != 0 else { return 0 }
    return Int(round(((current - previous) / previous) * 100))
}

private func signedPercent(_ value: Int) -> String {
    value >= 0 ? "+\(value)%" : "\(value)%"
}

private func actionLine(for goal: FinancialGoal) -> String {
    switch goal {
    case .saveMore: return L10n("ai.answer.action.save_more")
    case .payDebt: return L10n("ai.answer.action.pay_debt")
    case .controlSpending: return L10n("ai.answer.action.control_spending")
    }
}

private func findEmergencyGoal(in goals: [Goal]) -> Goal? {
    let normalizedNeedles = ["emergency", "awaryj"]
    if let match = goals.first(where: { goal in
        let name = normalize(goal.title)
        return normalizedNeedles.contains(where: { name.contains($0) })
    }) {
        return match
    }
    return goals.first
}

private func burnPaceAnswer(_ context: RichAnalyticsContext) -> String {
    let calendar = Calendar.current
    let isCurrentMonth = calendar.isDate(context.referenceMonth, equalTo: Date(), toGranularity: .month)
    let daysInMonth = calendar.range(of: .day, in: .month, for: context.referenceMonth)?.count ?? 30
    guard isCurrentMonth else {
        return String(format: L10n("ai.answer.burn_pace.past"), money(context.monthlyExpenses, context.currencyCode), context.referenceMonthDisplayString)
    }
    let elapsed = max(1, calendar.component(.day, from: Date()))
    let projected = (context.monthlyExpenses / Double(elapsed)) * Double(daysInMonth)
    let delta = projected - context.monthlyIncome
    return String(format: L10n("ai.answer.burn_pace.current"), money(projected, context.currencyCode), money(context.monthlyIncome, context.currencyCode), signedMoney(delta, context.currencyCode))
}

private func categoryDrillAnswer(_ context: RichAnalyticsContext) -> String {
    let query = normalize(context.userQuestion)
    let candidates = context.categorySpending.filter { query.contains(normalize($0.displayName)) }
    if let match = candidates.first {
        return String(format: L10n("ai.answer.category_drill.match"), match.displayName, money(match.amount, context.currencyCode))
    }
    
    let builtinHints: [(String, [String])] = [
        (L10n("category.food"), ["food", "jedzenie"]),
        (L10n("category.transport"), ["transport", "dojazd", "samochod"]),
        (L10n("category.rent"), ["rent", "czynsz", "mieszkanie"]),
        (L10n("category.entertainment"), ["entertainment", "rozrywka"]),
        (L10n("category.subscriptions"), ["subscriptions", "subskrypcje"]),
        (L10n("category.other"), ["other", "inne"])
    ]
    if let aliasMatch = builtinHints.first(where: { _, aliases in aliases.contains(where: { query.contains(normalize($0)) }) }) {
        if let bucket = context.categorySpending.first(where: { normalize($0.displayName) == normalize(aliasMatch.0) }) {
            return String(format: L10n("ai.answer.category_drill.match"), bucket.displayName, money(bucket.amount, context.currencyCode))
        }
    }
    
    let topHints = Array(context.categorySpending.prefix(2)).map(\.displayName).joined(separator: ", ")
    return topHints.isEmpty ? L10n("ai.answer.category_drill.no_match") : String(format: L10n("ai.answer.category_drill.suggest"), topHints)
}

private func whatIfCutAnswer(_ context: RichAnalyticsContext) -> String {
    let query = normalize(context.userQuestion)
    let requestedPercent = extractPercent(from: query) ?? 20
    let entertainmentName = L10n("category.entertainment")
    let bucket = context.categorySpending.first {
        let name = normalize($0.displayName)
        return name.contains(normalize(entertainmentName)) || query.contains("entertainment") || query.contains("rozrywka")
    }
    guard let category = bucket else {
        return L10n("ai.answer.what_if_cut.no_category")
    }
    let savings = category.amount * (Double(requestedPercent) / 100.0)
    return String(format: L10n("ai.answer.what_if_cut"), requestedPercent, category.displayName, money(savings, context.currencyCode))
}

private func extractPercent(from normalizedQuestion: String) -> Int? {
    let digits = normalizedQuestion.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    return digits.first(where: { $0 > 0 && $0 <= 100 })
}

private func biggestChangeAnswer(_ context: RichAnalyticsContext) -> String {
    var previousMap: [String: Double] = [:]
    for item in context.previousMonthCategorySpending {
        previousMap[normalize(item.displayName)] = item.amount
    }
    var bestName: String?
    var bestDelta: Double = 0
    for current in context.categorySpending {
        let prev = previousMap[normalize(current.displayName)] ?? 0
        let delta = current.amount - prev
        if abs(delta) > abs(bestDelta) {
            bestDelta = delta
            bestName = current.displayName
        }
    }
    guard let name = bestName else { return L10n("ai.answer.biggest_change.empty") }
    return String(format: L10n("ai.answer.biggest_change"), name, signedMoney(bestDelta, context.currencyCode))
}

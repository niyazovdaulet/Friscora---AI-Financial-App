//
//  GoalService.swift
//  Friscora
//
//  Service for managing goals using UserDefaults
//

import Foundation
import Combine

/// Goal activity entry
struct GoalActivity: Identifiable, Codable {
    let id: UUID
    let goalId: UUID
    let amount: Double
    let date: Date
    let note: String?
    
    init(id: UUID = UUID(), goalId: UUID, amount: Double, date: Date, note: String? = nil) {
        self.id = id
        self.goalId = goalId
        self.amount = amount
        self.date = date
        self.note = note
    }
}

/// Service for managing goals
class GoalService: ObservableObject {
    static let shared = GoalService()
    
    @Published var goals: [Goal] = []
    @Published var activities: [GoalActivity] = []
    
    private let goalsKey = "saved_goals"
    private let activitiesKey = "saved_goal_activities"
    
    private init() {
        loadGoals()
        loadActivities()
        NotificationCenter.default.addObserver(self, selector: #selector(handleICloudSyncUpdate), name: .ICloudSyncDidUpdate, object: nil)
    }
    
    @objc private func handleICloudSyncUpdate() {
        loadGoals()
        loadActivities()
    }
    
    /// Load goals from UserDefaults
    func loadGoals() {
        if let data = UserDefaults.standard.data(forKey: goalsKey),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            // Migrate old goals without currency to current currency
            let currentCurrency = UserProfileService.shared.profile.currency
            var needsSave = false
            goals = decoded.map { goal in
                var updatedGoal = goal
                // If goal doesn't have currency (old data), set it to current currency
                // This handles backward compatibility
                if updatedGoal.currency == nil {
                    updatedGoal.currency = currentCurrency
                    needsSave = true
                }
                return updatedGoal
            }.sorted { $0.createdDate > $1.createdDate }
            
            if needsSave {
                saveGoals() // Save migrated goals
            }
        }
    }
    
    /// Load activities from UserDefaults
    func loadActivities() {
        if let data = UserDefaults.standard.data(forKey: activitiesKey),
           let decoded = try? JSONDecoder().decode([GoalActivity].self, from: data) {
            activities = decoded
        }
    }
    
    /// Save goals to UserDefaults
    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: goalsKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    /// Save activities to UserDefaults
    private func saveActivities() {
        if let encoded = try? JSONEncoder().encode(activities) {
            UserDefaults.standard.set(encoded, forKey: activitiesKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    /// Add a new goal
    func addGoal(_ goal: Goal) {
        goals.insert(goal, at: 0) // Add to top
        saveGoals()
        
        // Debug print
        print("🎯 [GOAL CREATED]")
        print("   Title: \(goal.title)")
        print("   Target: \(goal.targetAmount) \(goal.effectiveCurrency)")
        print("   Current: \(goal.currentAmount) \(goal.effectiveCurrency)")
        if let deadline = goal.deadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            print("   Deadline: \(formatter.string(from: deadline))")
        }
        print("─────────────────────────────────────────")
    }
    
    /// Update a goal
    func updateGoal(_ goal: Goal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            saveGoals()
        }
    }
    
    /// Convert all goals to a new currency
    func convertGoals(from oldCurrency: String, to newCurrency: String) async {
        let currencyService = CurrencyService.shared
        
        for index in goals.indices {
            var goal = goals[index]
            let goalCurrency = goal.effectiveCurrency
            if goalCurrency != newCurrency {
                do {
                    // Convert target amount
                    let convertedTarget = try await currencyService.convert(
                        amount: goal.targetAmount,
                        from: goalCurrency,
                        to: newCurrency
                    )
                    
                    // Convert current amount
                    let convertedCurrent = try await currencyService.convert(
                        amount: goal.currentAmount,
                        from: goalCurrency,
                        to: newCurrency
                    )
                    
                    goal.targetAmount = convertedTarget
                    goal.currentAmount = convertedCurrent
                    goal.currency = newCurrency
                    goals[index] = goal
                } catch {
                    print("Failed to convert goal: \(error)")
                }
            }
        }
        saveGoals()
    }
    
    /// Delete a goal
    func deleteGoal(_ goal: Goal) {
        let goalActivities = activities.filter { $0.goalId == goal.id }
        let totalAllocated = goalActivities.reduce(0) { $0 + $1.amount }
        
        goals.removeAll { $0.id == goal.id }
        // Also remove related activities
        activities.removeAll { $0.goalId == goal.id }
        saveGoals()
        saveActivities()
        
        // Debug print
        print("🗑️ [GOAL DELETED]")
        print("   Title: \(goal.title)")
        print("   Target: \(goal.targetAmount) \(goal.effectiveCurrency)")
        print("   Current Progress: \(goal.currentAmount) \(goal.effectiveCurrency)")
        print("   Total Allocated: \(totalAllocated) \(goal.effectiveCurrency)")
        print("   ⚠️ This goal's allocations are removed from balance calculations")
        print("─────────────────────────────────────────")
    }
    
    /// Add activity to a goal
    func addActivity(_ activity: GoalActivity) {
        activities.append(activity)
        saveActivities()
        
        // Update goal's current amount
        if let index = goals.firstIndex(where: { $0.id == activity.goalId }) {
            var updatedGoal = goals[index]
            let oldAmount = updatedGoal.currentAmount
            updatedGoal.currentAmount += activity.amount
            updatedGoal.currentAmount = min(updatedGoal.currentAmount, updatedGoal.targetAmount)
            updatedGoal.isCompleted = updatedGoal.currentAmount >= updatedGoal.targetAmount
            goals[index] = updatedGoal
            saveGoals()
            
            // Debug print
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let currency = updatedGoal.effectiveCurrency
            print("💎 [GOAL PROGRESS ADDED]")
            print("   Goal: \(updatedGoal.title)")
            print("   Amount Added: \(activity.amount) \(currency)")
            print("   Previous Progress: \(oldAmount) \(currency)")
            print("   New Progress: \(updatedGoal.currentAmount) \(currency)")
            print("   Target: \(updatedGoal.targetAmount) \(currency)")
            print("   Progress: \(Int(updatedGoal.progress * 100))%")
            print("   Date: \(formatter.string(from: activity.date))")
            if let note = activity.note {
                print("   Note: \(note)")
            }
            print("   ⚠️ This amount is DEDUCTED from remaining balance!")
            let monthTotal = totalGoalAllocationsForMonth(activity.date)
            print("   Month Total Goal Allocations: \(monthTotal) \(UserProfileService.shared.profile.currency)")
            print("─────────────────────────────────────────")
        }
    }
    
    /// Remove a goal activity (e.g. from transaction history). Reverses the amount from the goal's current progress.
    func removeActivity(_ activity: GoalActivity) {
        activities.removeAll { $0.id == activity.id }
        saveActivities()
        if let index = goals.firstIndex(where: { $0.id == activity.goalId }) {
            var updatedGoal = goals[index]
            updatedGoal.currentAmount = max(0, updatedGoal.currentAmount - activity.amount)
            updatedGoal.isCompleted = updatedGoal.currentAmount >= updatedGoal.targetAmount
            goals[index] = updatedGoal
            saveGoals()
        }
    }
    
    /// Get activities for a specific goal
    func activitiesForGoal(_ goalId: UUID) -> [GoalActivity] {
        activities.filter { $0.goalId == goalId }
            .sorted { $0.date > $1.date }
    }
    
    /// Get active goals (not completed)
    var activeGoals: [Goal] {
        goals.filter { !$0.isCompleted }
            .sorted { $0.createdDate > $1.createdDate }
    }
    
    /// Get completed goals
    var completedGoals: [Goal] {
        goals.filter { $0.isCompleted }
            .sorted { $0.createdDate > $1.createdDate }
    }
    
    /// Get total goal allocations for a specific month
    func totalGoalAllocationsForMonth(_ date: Date) -> Double {
        let calendar = Calendar.current
        let monthActivities = activities.filter { activity in
            calendar.isDate(activity.date, equalTo: date, toGranularity: .month)
        }
        return monthActivities.reduce(0) { $0 + $1.amount }
    }
    
    /// Get goal activities for a specific month
    func activitiesForMonth(_ date: Date) -> [GoalActivity] {
        let calendar = Calendar.current
        return activities.filter { activity in
            calendar.isDate(activity.date, equalTo: date, toGranularity: .month)
        }.sorted { $0.date > $1.date }
    }
    
    /// Get active goals with their current progress
    func activeGoalsWithProgress() -> [Goal] {
        return activeGoals
    }
}


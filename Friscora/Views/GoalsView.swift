//
//  GoalsView.swift
//  Friscora
//
//  View for managing financial goals
//

import SwiftUI
import UIKit

struct GoalsView: View {
    @StateObject private var goalService = GoalService.shared
    @State private var showingAddGoal = false
    @State private var selectedTab = 0
    @State private var showCongratulations = false
    @State private var completedGoalTitle: String = ""
    @State private var completedGoalTargetAmount: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Primary background color
                AppColorTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab selector (matching Add View style)
                    tabSelectorSection
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Scrollable content using TabView
                    TabView(selection: $selectedTab) {
                    ScrollView {
                        VStack(spacing: 16) {
                            activeGoalsView
                        }
                        .padding()
                    }
                    .tag(0)
                    .animation(AppAnimation.listItem, value: goalService.activeGoals.count)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            completedGoalsView
                        }
                        .padding()
                    }
                    .tag(1)
                    .animation(AppAnimation.listItem, value: goalService.completedGoals.count)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle(L10n("goals.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text(L10n("goals.new_goal"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(AppColorTheme.goalsAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView()
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .fullScreenCover(isPresented: $showCongratulations) {
                CongratulateGoalView(
                    goalTitle: completedGoalTitle,
                    targetAmount: completedGoalTargetAmount
                )
            }
        }
    }
    
    // MARK: - Tab Selector (matching Add View style with swipe support)
    private var tabSelectorSection: some View {
        HStack(spacing: 0) {
            // Active button
            Button {
                HapticHelper.selection()
                withAnimation(AppAnimation.tabSwitch) {
                    selectedTab = 0
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title3)
                    Text(L10n("goals.active"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedTab == 0 ?
                    AppColorTheme.goalsAccentGradient : nil
                )
                .foregroundColor(selectedTab == 0 ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                .cornerRadius(16)
            }
            
            // Completed button
            Button {
                HapticHelper.selection()
                withAnimation(AppAnimation.tabSwitch) {
                    selectedTab = 1
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text(L10n("goals.completed"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedTab == 1 ?
                    AppColorTheme.goalsCompletedGradient : nil
                )
                .foregroundColor(selectedTab == 1 ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                .cornerRadius(16)
            }
        }
        .background(AppColorTheme.elevatedBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
    
    private var activeGoalsView: some View {
        Group {
            if goalService.activeGoals.isEmpty {
                EmptyStateView(
                    icon: "target",
                    message: L10n("goals.no_active_goals"),
                    detail: L10n("goals.set_first_goal"),
                    actionTitle: L10n("goals.create_first_goal"),
                    action: { showingAddGoal = true }
                )
                .padding(.vertical, AppSpacing.l)
            } else {
                ForEach(goalService.activeGoals) { goal in
                    let goalBinding = Binding(
                        get: { 
                            goalService.goals.first(where: { $0.id == goal.id }) ?? goal
                        },
                        set: { newValue in
                            goalService.updateGoal(newValue)
                        }
                    )
                    
                    GoalCard(
                        goal: goalBinding,
                        onGoalCompleted: { goalTitle, targetAmount in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                completedGoalTitle = goalTitle
                                completedGoalTargetAmount = targetAmount
                                withAnimation(AppAnimation.sheetPresent) {
                                    showCongratulations = true
                                }
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
    }
    
    private var completedGoalsView: some View {
        Group {
if goalService.completedGoals.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle.fill",
                    message: L10n("goals.no_completed_goals"),
                    detail: L10n("goals.complete_goals_message"),
                    iconColor: AppColorTheme.positive
                )
                .padding(.vertical, 60)
            } else {
                ForEach(goalService.completedGoals) { goal in
                    GoalCard(goal: Binding(
                        get: { 
                            goalService.goals.first(where: { $0.id == goal.id }) ?? goal
                        },
                        set: { newValue in
                            goalService.updateGoal(newValue)
                        }
                    ))
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
    }
}

struct GoalCard: View {
    @Binding var goal: Goal
    @State private var showEditSheet = false
    @State private var animatedProgress: Double = 0
    var onGoalCompleted: ((String, Double) -> Void)? = nil
    
    var body: some View {
        Button {
            withAnimation(AppAnimation.sheetPresent) {
                showEditSheet = true
            }
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showEditSheet) {
            EditGoalView(
                goal: $goal,
                onGoalCompleted: onGoalCompleted
            )
        }
        .onAppear {
            // Slight delay before progress updates (feels intentional)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                // Progress bar animation with ease-out
                withAnimation(AppAnimation.goalCelebration) {
                    animatedProgress = goal.progress
                }
            }
        }
        .onChange(of: goal.progress) { newProgress in
            // Slight delay before progress updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Animate when progress changes with ease-out
                withAnimation(AppAnimation.goalCelebration) {
                    animatedProgress = newProgress
                }
            }
        }
        .onChange(of: goal.isCompleted) { isCompleted in
            if isCompleted {
                // Soft haptic when goal completes
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // When marked as completed, animate to 100% with ease-out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(AppAnimation.goalCelebrationFinal) {
                        animatedProgress = 1.0
                    }
                }
            }
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            progressSection
            actionHint
        }
        .padding(20)
        .background(AppColorTheme.goalsCardGradient)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorTheme.textPrimary)
                
                if let deadline = goal.deadline {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(AppColorTheme.textSecondary)
                        Text(deadline, style: .date)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                        
                        // Pace indicator
                        if let pace = goal.paceIndicator, !goal.isCompleted {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: paceIcon(pace))
                                    .font(.caption2)
                                Text(pace)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(paceColor(pace))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(paceColor(pace).opacity(0.15))
                            )
                        }
                    }
                }
            }
            
            Spacer()
            
            if goal.isCompleted {
                ZStack {
                    Circle()
                        .fill(AppColorTheme.goalsCompleted)
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColorTheme.textPrimary)
                }
            }
        }
    }
    
    private func paceIcon(_ pace: String) -> String {
        switch pace {
        case "Ahead": return "arrow.up.circle.fill"
        case "Behind": return "arrow.down.circle.fill"
        case "On track": return "checkmark.circle.fill"
        default: return "circle.fill"
        }
    }
    
    private func paceColor(_ pace: String) -> Color {
        switch pace {
        case "Ahead": return AppColorTheme.goalsSecondaryAccent
        case "Behind": return AppColorTheme.negative
        case "On track": return AppColorTheme.goalsAccent
        default: return AppColorTheme.textSecondary
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            amountDisplay
            progressBar
            progressPercentage
        }
    }
    
    private var amountDisplay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n("goals.current"))
                    .font(.caption2)
                    .foregroundColor(AppColorTheme.textSecondary)
                Text(formatCurrency(goal.currentAmount))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n("goals.target"))
                    .font(.caption2)
                    .foregroundColor(AppColorTheme.textSecondary)
                Text(formatCurrency(goal.targetAmount))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
        }
    }
    
    @ViewBuilder
    private var progressBar: some View {
        if goal.isCompleted {
            // Completed state: thin line + checkmark
            HStack(spacing: 8) {
                Rectangle()
                    .fill(AppColorTheme.goalsCompleted.opacity(0.4))
                    .frame(height: 2)
                    .cornerRadius(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColorTheme.goalsCompleted)
                    Text(L10n("goals.completed"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColorTheme.goalsCompleted.opacity(0.9))
                }
            }
        } else {
            // Active state: context-aware progress bar
            GeometryReader { geometry in
                let progress = animatedProgress
                let intensity: Double = progress < 0.3 ? 0.3 : (progress < 0.8 ? 0.7 : 1.0)
                let progressGradient: LinearGradient = {
                    if progress < 0.3 {
                        // <30%: muted
                        return LinearGradient(
                            colors: [
                                AppColorTheme.goalsAccent.opacity(0.4),
                                AppColorTheme.goalsAccent.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else if progress < 0.8 {
                        // 30-80%: normal
                        return LinearGradient(
                            colors: [
                                AppColorTheme.goalsAccent.opacity(0.8),
                                AppColorTheme.goalsAccent.opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        // 80-100%: elegant highlight
                        return LinearGradient(
                            colors: [
                                AppColorTheme.goalsAccent,
                                AppColorTheme.goalsAccent.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }()
                
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColorTheme.grayDark.opacity(0.5))
                        .frame(height: 12)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 12)
                        .shadow(
                            color: AppColorTheme.goalsAccent.opacity(0.3 * intensity),
                            radius: 4 * intensity,
                            x: 0,
                            y: 1
                        )
                    
                    // Checkmark animation at 100%
                    if progress >= 1.0 {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColorTheme.textPrimary)
                                .padding(.trailing, 4)
                        }
                    }
                }
            }
            .frame(height: 12)
        }
    }
    
    private var progressPercentage: some View {
        HStack {
            Text(String(format: L10n("goals.percent_complete"), Int(goal.progress * 100)))
                .font(.caption)
                .foregroundColor(AppColorTheme.textSecondary)
            Spacer()
            if !goal.isCompleted {
                Text(String(format: L10n("goals.percent_remaining"), Int((1 - goal.progress) * 100)))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            }
        }
    }
    
    private var actionHint: some View {
        Group {
            if !goal.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColorTheme.goalsAccent)
                    Text(L10n("goals.update_progress"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.goalsAccent)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
}

// Goal template structure
struct GoalTemplate: Identifiable {
    let id = UUID()
    let title: String
    let localizationKey: String
    let suggestedAmount: Double?
    let suggestedDeadline: Date?
    let icon: String
    
    /// Localized template name for the current app language.
    var localizedTitle: String {
        L10n(localizationKey)
    }
    
    static let templates: [GoalTemplate] = [
        GoalTemplate(
            title: "Emergency Fund",
            localizationKey: "goals.template_emergency",
            suggestedAmount: 10000,
            suggestedDeadline: Calendar.current.date(byAdding: .month, value: 12, to: Date()),
            icon: "shield.fill"
        ),
        GoalTemplate(
            title: "Vacation",
            localizationKey: "goals.template_vacation",
            suggestedAmount: 5000,
            suggestedDeadline: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            icon: "airplane"
        ),
        GoalTemplate(
            title: "Freedom Fund",
            localizationKey: "goals.template_freedom",
            suggestedAmount: 50000,
            suggestedDeadline: Calendar.current.date(byAdding: .year, value: 2, to: Date()),
            icon: "star.fill"
        ),
        GoalTemplate(
            title: "Debt Payoff",
            localizationKey: "goals.template_debt",
            suggestedAmount: nil, // User should enter their debt amount
            suggestedDeadline: Calendar.current.date(byAdding: .month, value: 24, to: Date()),
            icon: "creditcard.fill"
        )
    ]
}

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var goalService = GoalService.shared
    
    @State private var title: String = ""
    @State private var targetAmount: String = ""
    @State private var targetAmountDisplay: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var showTemplates: Bool = true
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Primary background color
                AppColorTheme.background
                    .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Goal templates card
                            if showTemplates {
                                goalTemplatesCard
                            }
                            
                            // Goal title card
                            goalTitleCard
                            
                            // Target amount card
                            targetAmountCard
                                .id("targetAmount")
                            
                            // Deadline card
                            deadlineCard
                        }
                        .padding()
                        .keyboardAvoiding()
                    }
                    .onChange(of: isAmountFocused) { _, focused in
                        if focused {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo("targetAmount", anchor: .center)
                            }
                        }
                    }
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle(L10n("goals.new_goal_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(AppColorTheme.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
                        saveGoal()
                    }
                    .foregroundColor(canSave ? AppColorTheme.accent : AppColorTheme.textTertiary)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTitleFocused = true
                }
            }
        }
    }
    
    private var canSave: Bool {
        !title.isEmpty && !targetAmount.isEmpty && (CurrencyFormatter.parsedAmount(from: targetAmount) ?? 0) > 0
    }
    
    // MARK: - Goal Templates Card
    private var goalTemplatesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(AppColorTheme.goalsAccent.opacity(0.8))
                        Text(L10n("goals.goal_templates"))
                            .font(.headline)
                            .foregroundColor(AppColorTheme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(AppAnimation.standard) {
                            showTemplates.toggle()
                        }
                    } label: {
                        Image(systemName: showTemplates ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
                
                Text(L10n("goals.start_with_suggestion"))
                    .font(.subheadline)
                    .foregroundColor(AppColorTheme.textSecondary)
            }
            
            if showTemplates {
                VStack(spacing: 10) {
                    ForEach(GoalTemplate.templates) { template in
                        Button {
                            HapticHelper.selection()
                            applyTemplate(template)
                            withAnimation(AppAnimation.standard) {
                                showTemplates = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                let confirmGenerator = UINotificationFeedbackGenerator()
                                confirmGenerator.notificationOccurred(.success)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColorTheme.goalsAccent.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: template.icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(AppColorTheme.goalsAccent.opacity(0.8))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.localizedTitle)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColorTheme.textPrimary)
                                    
                                    if let amount = template.suggestedAmount {
                                        Text(String(format: L10n("goals.suggested_amount"), formatCurrency(amount)))
                                            .font(.caption)
                                            .foregroundColor(AppColorTheme.textSecondary)
                                    } else {
                                        Text(L10n("goals.enter_amount"))
                                            .font(.caption)
                                            .foregroundColor(AppColorTheme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppColorTheme.textTertiary)
                            }
                            .padding(12)
                            .background(AppColorTheme.elevatedBackground.opacity(0.6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    AppColorTheme.goalsCardTop.opacity(0.7),
                    AppColorTheme.goalsCardBottom.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    private func applyTemplate(_ template: GoalTemplate) {
        title = template.localizedTitle
        if let amount = template.suggestedAmount {
            targetAmount = String(format: "%.2f", amount)
            targetAmountDisplay = CurrencyFormatter.formatAmountForDisplay(targetAmount)
        }
        if let suggestedDeadline = template.suggestedDeadline {
            deadline = suggestedDeadline
            hasDeadline = true
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
    
    // MARK: - Goal Title Card
    private var goalTitleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.goalsAccent)
                Text(L10n("goals.goal_title"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            
            TextField(L10n("goals.enter_goal_title"), text: $title)
                .focused($isTitleFocused)
                .font(.body)
                .foregroundColor(AppColorTheme.textPrimary)
                .padding(18)
                .background(AppColorTheme.elevatedBackground.opacity(0.5))
                .cornerRadius(14)
        }
        .padding(24)
        .background(AppColorTheme.goalsCardGradient)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Target Amount Card
    private var targetAmountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.goalsAccent)
                Text(L10n("goals.target_amount"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            
            HStack(spacing: 12) {
                // Currency badge
                Text(UserProfileService.shared.profile.currency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColorTheme.goalsAccentGradient)
                    .cornerRadius(12)
                
                // Custom numeric keyboard (period = decimal, comma = grouping)
                AmountInputWithCustomKeyboard(
                    amountDisplay: $targetAmountDisplay,
                    focusTrigger: 0,
                    onFormatChange: { targetAmount = $0 },
                    onFocusChange: { isAmountFocused = $0 }
                )
                .onAppear {
                    targetAmountDisplay = CurrencyFormatter.formatAmountForDisplay(targetAmount)
                }
            }
        }
        .padding(24)
        .background(AppColorTheme.goalsCardGradient)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Deadline Card
    private var deadlineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.goalsAccent)
                Text(L10n("goals.deadline"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $hasDeadline) {
                    Text(L10n("goals.set_deadline"))
                        .foregroundColor(AppColorTheme.textPrimary)
                }
                .tint(AppColorTheme.goalsAccent)
                
                Text(L10n("goals.deadline_help"))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .padding(.leading, 4)
            }
            
            if hasDeadline {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(AppColorTheme.goalsAccent)
                        .font(.title3)
                    
                    AutoDismissDatePicker(
                        selection: $deadline,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    
                    Spacer()
                }
                .padding(18)
                .background(AppColorTheme.elevatedBackground.opacity(0.5))
                .cornerRadius(14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(24)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .animation(AppAnimation.standard, value: hasDeadline)
    }
    
    private func saveGoal() {
        guard let amount = CurrencyFormatter.parsedAmount(from: targetAmount), amount > 0 else { return }
        
        let goal = Goal(
            title: title,
            targetAmount: amount,
            deadline: hasDeadline ? deadline : nil
        )
        
        HapticHelper.mediumImpact()
        withAnimation(AppAnimation.listItem) {
            goalService.addGoal(goal)
        }
        dismiss()
    }
}

struct EditGoalView: View {
    @Binding var goal: Goal
    @Environment(\.dismiss) private var dismiss
    @StateObject private var goalService = GoalService.shared
    var onGoalCompleted: ((String, Double) -> Void)? = nil
    
    @State private var title: String
    @State private var targetAmount: String
    @State private var targetAmountDisplay: String
    @State private var isCompleted: Bool
    @State private var addAmount: String = ""
    @State private var addAmountDisplay: String = ""
    @State private var addNote: String = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isAddAmountFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    init(goal: Binding<Goal>, onGoalCompleted: ((String, Double) -> Void)? = nil) {
        _goal = goal
        _title = State(initialValue: goal.wrappedValue.title)
        _targetAmount = State(initialValue: String(format: "%.2f", goal.wrappedValue.targetAmount))
        _targetAmountDisplay = State(initialValue: CurrencyFormatter.formatAmountForDisplay(String(format: "%.2f", goal.wrappedValue.targetAmount)))
        _isCompleted = State(initialValue: goal.wrappedValue.isCompleted)
        self.onGoalCompleted = onGoalCompleted
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Primary background color
                AppColorTheme.background
                    .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Goal title card
                            goalTitleCard
                            
                            // Target amount card
                            targetAmountCard
                                .id("targetAmount")
                            
                            // Current amount card (read-only)
                            currentAmountCard
                            
                            // Add progress card
                            addProgressCard
                                .id("addProgress")
                            
                            // Recent activity card
                            recentActivityCard
                            
                            // Completion and Delete section (combined at bottom)
                            completionAndDeleteCard
                        }
                        .padding()
                        .keyboardAvoiding()
                    }
                    .onChange(of: isAmountFocused) { _, focused in
                        if focused {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo("targetAmount", anchor: .center)
                            }
                        }
                    }
                    .onChange(of: isAddAmountFocused) { _, focused in
                        if focused {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo("addProgress", anchor: .center)
                            }
                        }
                    }
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle(L10n("goals.update_goal_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(AppColorTheme.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
                        saveGoal()
                    }
                    .foregroundColor(AppColorTheme.accent)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .alert(L10n("goals.delete_goal"), isPresented: $showDeleteConfirmation) {
                Button(L10n("common.cancel"), role: .cancel) { }
                Button(L10n("common.delete"), role: .destructive) {
                    deleteGoal()
                }
            } message: {
                Text(L10n("goals.delete_confirm"))
            }
        }
    }
    
    // MARK: - Goal Title Card
    private var goalTitleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.accent)
                Text(L10n("goals.goal_title"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            
            TextField(L10n("goals.enter_goal_title"), text: $title)
                .focused($isTitleFocused)
                .font(.body)
                .foregroundColor(AppColorTheme.textPrimary)
                .padding(16)
                .background(AppColorTheme.elevatedBackground)
                .cornerRadius(12)
        }
        .padding(20)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Target Amount Card
    private var targetAmountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.accent)
                        Text("Target Amount")
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            
            HStack(spacing: 12) {
                // Currency badge
                Text(UserProfileService.shared.profile.currency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColorTheme.accentGradient)
                    .cornerRadius(12)
                
                // Custom numeric keyboard (period = decimal, comma = grouping)
                AmountInputWithCustomKeyboard(
                    amountDisplay: $targetAmountDisplay,
                    focusTrigger: 0,
                    onFormatChange: { targetAmount = $0 },
                    onFocusChange: { isAmountFocused = $0 }
                )
                .onAppear {
                    targetAmountDisplay = CurrencyFormatter.formatAmountForDisplay(targetAmount)
                }
            }
        }
        .padding(20)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Current Amount Card
    private var currentAmountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.accent)
                Text(L10n("goals.current_progress"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                    }
                    
                    HStack {
                VStack(alignment: .leading, spacing: 4) {
                        Text(L10n("goals.current_amount"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                        Text(formatCurrency(goal.currentAmount))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColorTheme.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n("goals.progress"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    Text("\(Int(goal.progress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColorTheme.accent)
                }
            }
            .padding(16)
            .background(AppColorTheme.elevatedBackground)
            .cornerRadius(12)
        }
        .padding(20)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Completion and Delete Card (Combined)
    private var completionAndDeleteCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Completion Status Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColorTheme.accent)
                    Text(L10n("goals.completion_status"))
                        .font(.headline)
                        .foregroundColor(AppColorTheme.textPrimary)
                }
                
                Toggle(isOn: $isCompleted) {
                    Text(L10n("goals.mark_completed"))
                        .foregroundColor(AppColorTheme.textPrimary)
                }
                .tint(AppColorTheme.accent)
            }
            
            // Divider
            Rectangle()
                .fill(AppColorTheme.grayDark)
                .frame(height: 1)
            
            // Delete Button Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .foregroundColor(AppColorTheme.negative)
                    Text(L10n("goals.danger_zone"))
                        .font(.headline)
                        .foregroundColor(AppColorTheme.textPrimary)
                }
                
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.title3)
                        Text(L10n("goals.delete_goal"))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColorTheme.negativeGradient)
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Add Progress Card
    private var addProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.accent)
                Text(L10n("goals.add_progress"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            
            HStack(spacing: 12) {
                // Currency badge
                Text(UserProfileService.shared.profile.currency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColorTheme.accentGradient)
                    .cornerRadius(12)
                
                // Custom numeric keyboard (period = decimal, comma = grouping)
                AmountInputWithCustomKeyboard(
                    amountDisplay: $addAmountDisplay,
                    focusTrigger: 0,
                    onFormatChange: { addAmount = $0 },
                    onFocusChange: { isAddAmountFocused = $0 }
                )
                .onAppear {
                    addAmountDisplay = CurrencyFormatter.formatAmountForDisplay(addAmount)
                }
            }
            
            TextField("Note (optional)", text: $addNote, axis: .vertical)
                .focused($isNoteFocused)
                .font(.body)
                .foregroundColor(AppColorTheme.textPrimary)
                .lineLimit(3...6)
                .padding(16)
                .background(AppColorTheme.elevatedBackground)
                .cornerRadius(12)
                    
                    if let addAmountValue = CurrencyFormatter.parsedAmount(from: addAmount), addAmountValue > 0 {
                        let remaining = goal.targetAmount - goal.currentAmount
                        if remaining > 0 && addAmountValue > remaining {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(AppColorTheme.warning)
                            Text(String(format: L10n("goals.add_more_remaining"), formatCurrency(remaining)))
                                .font(.caption)
                            .foregroundColor(AppColorTheme.warning)
                    }
                    .padding(12)
                    .background(AppColorTheme.warning.opacity(0.15))
                    .cornerRadius(8)
                        }
                    }
                    
                    Button {
                        addProgressToGoal()
                    } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                            Text(L10n("goals.add_to_goal"))
                        .fontWeight(.semibold)
                }
                .foregroundColor(AppColorTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canAddAmount ? 
                    AppColorTheme.accentGradient : 
                    LinearGradient(
                        colors: [AppColorTheme.grayDark, AppColorTheme.grayDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                    }
                    .disabled(!canAddAmount)
        }
        .padding(20)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Recent Activity Card
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.accent)
                Text(L10n("goals.recent_activity"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            
                    let activities = goalService.activitiesForGoal(goal.id)
                    
                    if activities.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.title2)
                        .foregroundColor(AppColorTheme.textSecondary)
                        Text(L10n("goals.no_activity_yet"))
                        .font(.subheadline)
                        .foregroundColor(AppColorTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                    } else {
                VStack(spacing: 12) {
                        ForEach(activities) { activity in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppColorTheme.accent.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(AppColorTheme.accent)
                            }
                            
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatCurrency(activity.amount))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColorTheme.textPrimary)
                                    
                                    Text(activity.date, style: .date)
                                        .font(.caption)
                                    .foregroundColor(AppColorTheme.textSecondary)
                                    
                                    if let note = activity.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                        .foregroundColor(AppColorTheme.textSecondary)
                                        .padding(.top, 2)
                                    }
                                }
                                
                                Spacer()
                            }
                        .padding(12)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(20)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    
    private var canAddAmount: Bool {
        // Check if amount field has valid input
        guard !addAmount.isEmpty,
              let amount = CurrencyFormatter.parsedAmount(from: addAmount),
              amount > 0 else {
            return false
        }
        
        // Always allow adding if there's a valid amount
        // The addProgressToGoal function will handle capping to remaining amount
        return true
    }
    
    private func addProgressToGoal() {
        guard let amount = CurrencyFormatter.parsedAmount(from: addAmount), amount > 0 else { return }
        let remaining = goal.targetAmount - goal.currentAmount
        
        // Only add up to the remaining amount
        let amountToAdd = min(amount, remaining)
        guard amountToAdd > 0 else { return }
        
        // Check if this will complete the goal (capture title and amount before any updates so congratulations shows correct value)
        let willComplete = (goal.currentAmount + amountToAdd) >= goal.targetAmount
        let goalTitle = goal.title
        let targetAmountForCongratulations = goal.targetAmount
        
        let activity = GoalActivity(
            goalId: goal.id,
            amount: amountToAdd,
            date: Date(),
            note: addNote.isEmpty ? nil : addNote
        )
        
        // Add activity (this automatically updates goal's currentAmount and isCompleted)
        goalService.addActivity(activity)
        
        // Reload goal from service to get updated state
        if let updatedGoal = goalService.goals.first(where: { $0.id == goal.id }) {
            goal = updatedGoal
        }
        
        // Save any other goal changes (title, target amount, etc.)
        saveGoalWithoutDismiss()
        
        // Clear input fields
        addAmount = ""
        addAmountDisplay = ""
        addNote = ""
        
        // If goal was completed, trigger congratulations callback with amount captured before save
        if willComplete {
            // Small delay for smooth transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss() // Dismiss EditGoalView first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onGoalCompleted?(goalTitle, targetAmountForCongratulations)
                }
            }
        }
    }
    
    private func saveGoalWithoutDismiss() {
        guard let newTargetAmount = CurrencyFormatter.parsedAmount(from: targetAmount), newTargetAmount > 0 else { return }
        
        // Ensure current amount doesn't exceed new target
        let finalCurrentAmount = min(goal.currentAmount, newTargetAmount)
        
        let updatedGoal = Goal(
            id: goal.id,
            title: title,
            targetAmount: newTargetAmount,
            currentAmount: finalCurrentAmount,
            deadline: goal.deadline,
            isCompleted: isCompleted || finalCurrentAmount >= newTargetAmount,
            createdDate: goal.createdDate,
            currency: goal.currency
        )
        
        HapticHelper.mediumImpact()
        withAnimation(AppAnimation.listItem) {
            goalService.updateGoal(updatedGoal)
        }
        goal = updatedGoal
    }
    
    private func saveGoal() {
        guard let newTargetAmount = CurrencyFormatter.parsedAmount(from: targetAmount), newTargetAmount > 0 else { return }
        
        // Ensure current amount doesn't exceed new target
        let finalCurrentAmount = min(goal.currentAmount, newTargetAmount)
        
        let updatedGoal = Goal(
            id: goal.id,
            title: title,
            targetAmount: newTargetAmount,
            currentAmount: finalCurrentAmount,
            deadline: goal.deadline,
            isCompleted: isCompleted || finalCurrentAmount >= newTargetAmount,
            createdDate: goal.createdDate,
            currency: goal.currency
        )
        
        HapticHelper.mediumImpact()
        withAnimation(AppAnimation.listItem) {
            goalService.updateGoal(updatedGoal)
        }
        goal = updatedGoal
        dismiss()
    }
    
    private func deleteGoal() {
        HapticHelper.mediumImpact()
        withAnimation(AppAnimation.listItem) {
            goalService.deleteGoal(goal)
        }
        dismiss()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
}

// MARK: - Congratulate Goal View
struct CongratulateGoalView: View {
    let goalTitle: String
    let targetAmount: Double
    @Environment(\.dismiss) private var dismiss
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var confettiTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                AppColorTheme.background
                    .ignoresSafeArea()
                    .onTapGesture {
                        confettiTimer?.invalidate()
                        dismiss()
                    }
                
                // Confetti particles (only animated ones)
                ForEach(confettiParticles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                }
                
                // Main content
                VStack(spacing: 30) {
                    // Celebration icon
                    ZStack {
                        Circle()
                            .fill(AppColorTheme.positiveGradient)
                            .frame(width: 120, height: 120)
                            .scaleEffect(scale)
                            .opacity(opacity)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 70, weight: .bold))
                            .foregroundColor(AppColorTheme.textPrimary)
                            .scaleEffect(scale)
                            .opacity(opacity)
                    }
                    
                    VStack(spacing: 16) {
                        // Congratulations text - single line with proper layout
                        HStack(spacing: 8) {
                            Text("🎉")
                            Text(L10n("goals.congratulations"))
                            Text("🎉")
                        }
                        .font(.system(size: min(geometry.size.width * 0.08, 32), weight: .bold))
                        .foregroundColor(AppColorTheme.textPrimary)
                        .opacity(opacity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        
                        Text(L10n("goals.completed_message"))
                            .font(.title3)
                            .foregroundColor(AppColorTheme.textSecondary)
                            .opacity(opacity)
                        
                        // Goal name and target amount
                        VStack(spacing: 8) {
                            Text(goalTitle)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorTheme.accent)
                            
                            Text(formatCurrency(targetAmount))
                                .font(.title3)
                                .foregroundColor(AppColorTheme.textSecondary)
                        }
                        .opacity(opacity)
                    }
                    
                    Text(L10n("goals.tap_to_continue"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                        .opacity(opacity)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .onAppear {
            // Animate main content
            withAnimation(AppAnimation.sheetPresent) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Only generate animated confetti
            startContinuousConfetti()
        }
        .onDisappear {
            confettiTimer?.invalidate()
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
    
    private func startContinuousConfetti() {
        let colors: [Color] = [
            AppColorTheme.accent,
            AppColorTheme.positive,
            AppColorTheme.balanceHighlight,
            Color.yellow,
            Color.orange,
            Color.pink
        ]
        
        let screenWidth = UIScreen.main.bounds.width
        
        // Continuously add new confetti particles
        confettiTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let randomX = Double.random(in: 0...screenWidth)
            let randomY = -50.0
            let randomSize = CGFloat.random(in: 8...16)
            let randomColor = colors.randomElement() ?? AppColorTheme.accent
            let randomAngle = Double.random(in: 0...(2 * .pi))
            
            let particle = ConfettiParticle(
                id: UUID(),
                position: CGPoint(x: randomX, y: randomY),
                size: randomSize,
                color: randomColor,
                angle: randomAngle,
                velocity: CGPoint(
                    x: cos(randomAngle) * Double.random(in: 1...3),
                    y: Double.random(in: 2...5)
                )
            )
            
            confettiParticles.append(particle)
            
            // Animate particle falling (but keep it visible)
            withAnimation(AppAnimation.confetti(duration: Double.random(in: 3...5))) {
                if let index = confettiParticles.firstIndex(where: { $0.id == particle.id }) {
                    let screenHeight = UIScreen.main.bounds.height
                    confettiParticles[index].position.y = screenHeight + 100
                }
            }
            
            // Remove particles that have fallen off screen after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if let index = confettiParticles.firstIndex(where: { $0.id == particle.id }) {
                    confettiParticles.remove(at: index)
                }
            }
        }
    }
}

// MARK: - Confetti Particle Model
struct ConfettiParticle: Identifiable {
    let id: UUID
    var position: CGPoint
    let size: CGFloat
    let color: Color
    let angle: Double
    let velocity: CGPoint
}

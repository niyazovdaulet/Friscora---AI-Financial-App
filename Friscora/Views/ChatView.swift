//
//  ChatView.swift
//  Friscora
//
//  AI chat interface for financial advice
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Binding var referenceMonth: Date
    let initialQuestion: String?
    @State private var didSendInitialQuestion = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(referenceMonth: Binding<Date> = .constant(Date()), initialQuestion: String? = nil) {
        _referenceMonth = referenceMonth
        self.initialQuestion = initialQuestion
        _viewModel = StateObject(wrappedValue: ChatViewModel(referenceMonth: referenceMonth.wrappedValue))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Primary background color
                AppColorTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Text(String(format: L10n("chat.reference_month_trust"), viewModel.referenceMonthDisplayString))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Messages list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                // Show template questions after first AI message (only if no user messages yet)
                                if let firstMessage = viewModel.messages.first,
                                   !firstMessage.isUser,
                                   !viewModel.messages.contains(where: { $0.isUser }) {
                                    TemplateQuestionsView(viewModel: viewModel)
                                }
                                
                                if viewModel.isLoading {
                                    HStack {
                                        ProgressView()
                                            .tint(AppColorTheme.accent)
                                            .padding()
                                        Text(L10n("chat.thinking"))
                                            .foregroundColor(AppColorTheme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastMessage = viewModel.messages.last {
                                withAnimation(AppAnimation.standard) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Disclaimer (only show when input is empty)
                    if viewModel.inputText.isEmpty {
                        Text(L10n("chat.disclaimer"))
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(AppColorTheme.cardBackground.opacity(0.5))
                            .transition(.opacity)
                    }
                    
                    // Input area
                    HStack(spacing: 12) {
                        TextField(L10n("chat.input_placeholder"), text: $viewModel.inputText, axis: .vertical)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(AppColorTheme.cardBackground.opacity(0.6))
                            .foregroundColor(AppColorTheme.textPrimary)
                            .cornerRadius(25)
                            .lineLimit(1...4)
                            .focused($isInputFocused)
                            .disabled(viewModel.isLoading)
                        
                        Button {
                            viewModel.sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(viewModel.inputText.isEmpty || viewModel.isLoading ? AppColorTheme.textTertiary : AppColorTheme.accent)
                        }
                        .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
                    }
                    .padding()
                    .background(AppColorTheme.background)
                }
            }
            .dismissKeyboardOnTap()
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .navigationTitle(L10n("chat.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body)
                                .fontWeight(.semibold)
                            Text(L10n("common.back"))
                                .font(.body)
                        }
                        .foregroundColor(AppColorTheme.accent)
                    }
                }
            }
            // Keep context aligned with the selected analytics month while chat is open.
            .onChange(of: referenceMonth) { _, newMonth in
                viewModel.updateReferenceMonth(newMonth)
            }
            .onAppear {
                guard !didSendInitialQuestion, let question = initialQuestion else { return }
                didSendInitialQuestion = true
                viewModel.sendQuestion(question)
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding()
                    .background(message.isUser ? AppColorTheme.accent : AppColorTheme.cardBackground)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(AppColorTheme.textSecondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct TemplateQuestionsView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    let templateQuestions = [
        L10n("ai.chip.biggest_driver"),
        L10n("ai.chip.income_vs_outflows"),
        L10n("ai.chip.savings_rate"),
        L10n("ai.chip.burn_pace"),
        L10n("ai.chip.top_three"),
        L10n("ai.chip.small_purchases"),
        L10n("ai.chip.mom_comparison"),
        L10n("ai.chip.goal_progress"),
        L10n("ai.chip.where_money_goes"),
        L10n("ai.chip.savings_vs_expenses"),
        L10n("ai.chip.leftover"),
        L10n("ai.chip.biggest_change")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n("chat.try_asking"))
                .font(.caption)
                .foregroundColor(AppColorTheme.textSecondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.s) {
                    ForEach(templateQuestions, id: \.self) { question in
                        Button {
                            viewModel.sendQuestion(question)
                        } label: {
                            Text(question)
                                .font(.subheadline)
                                .foregroundColor(AppColorTheme.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(AppColorTheme.cardBackground)
                                        .overlay(
                                            Capsule()
                                                .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                                        )
                                )
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
}


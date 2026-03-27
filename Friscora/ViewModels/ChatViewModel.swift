//
//  ChatViewModel.swift
//  Friscora
//
//  ViewModel for AI chat interface
//

import Foundation
import Combine

/// Chat message model
struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    
    private let aiService: AIServiceProtocol
    private let expenseService = ExpenseService.shared
    private let userProfileService = UserProfileService.shared
    
    init(aiService: AIServiceProtocol = MockAIService.shared) {
        self.aiService = aiService
        addWelcomeMessage()
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "Hello! I'm your AI financial adviser. I can help you understand your spending patterns, suggest ways to save money, and provide insights based on your financial data. What would you like to know?",
            isUser: false
        )
        messages.append(welcomeMessage)
    }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let question = inputText
        inputText = ""
        sendQuestion(question)
    }
    
    /// Send a question directly (e.g. from suggested questions) without using the text field.
    func sendQuestion(_ question: String) {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(content: question, isUser: true)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        
        Task {
            await getAIResponse(question: question)
        }
    }
    
    @MainActor
    private func getAIResponse(question: String) async {
        do {
            let context = AIContextBuilder.buildContext(
                userProfile: userProfileService.profile,
                expenses: expenseService.expenses,
                incomes: IncomeService.shared.incomes,
                userQuestion: question
            )
            
            let response = try await aiService.getAdvice(context: context)
            
            let aiMessage = ChatMessage(content: response, isUser: false)
            messages.append(aiMessage)
            isLoading = false
        } catch {
            let errorMessage = ChatMessage(
                content: "Sorry, I encountered an error. Please try again later.",
                isUser: false
            )
            messages.append(errorMessage)
            isLoading = false
        }
    }
}


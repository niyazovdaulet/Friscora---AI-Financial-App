//
//  PasscodeEntryView.swift
//  Friscora
//
//  Passcode entry view (Revolut style)
//

import SwiftUI
import UIKit

struct PasscodeEntryView: View {
    @Binding var passcode: String
    let title: String
    let subtitle: String?
    let onComplete: (() -> Void)?
    let maxDigits: Int = 4
    
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    
    init(passcode: Binding<String>,
         title: String = "Enter Passcode",
         subtitle: String? = nil,
         onComplete: (() -> Void)? = nil) {
        self._passcode = passcode
        self.title = title
        self.subtitle = subtitle
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title / subtitle — tap dismisses the number pad
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = false
            }

            // Dots row — full-width “passcode section”; tap refocuses the field
            HStack(spacing: 20) {
                ForEach(0..<maxDigits, id: \.self) { index in
                    Circle()
                        .fill(index < passcode.count ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                .opacity(index < passcode.count ? 0 : 1)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
            .offset(x: shakeOffset)
            .animation(AppAnimation.passcodeShake, value: shakeOffset)

            // Hidden text field for input
            TextField("", text: $passcode)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 0, height: 0)
                .onChange(of: passcode) { newValue in
                    // Limit to maxDigits
                    if newValue.count > maxDigits {
                        passcode = String(newValue.prefix(maxDigits))
                    }
                    
                    // Only allow digits
                    passcode = passcode.filter { $0.isNumber }
                    
                    // Trigger shake on invalid input
                    if newValue.count > maxDigits {
                        shakeAnimation()
                    }
                    
                    // Call completion when passcode is complete
                    if passcode.count == maxDigits {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onComplete?()
                        }
                    }
                }
        }
        .onAppear {
            // Auto-focus on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Re-focus when app returns from background so keyboard shows (task 4)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
    }
    
    private func shakeAnimation() {
        withAnimation(AppAnimation.quickUI) {
            shakeOffset = -10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(AppAnimation.quickUI) {
                shakeOffset = 10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(AppAnimation.quickUI) {
                shakeOffset = 0
            }
        }
    }
}


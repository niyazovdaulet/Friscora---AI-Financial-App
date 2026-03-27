//
//  LoadingScreenView.swift
//  Friscora
//
//  Full-screen overlay shown during app reload (e.g. after language change).
//  Uses AppColorTheme for consistent light/dark appearance.
//

import SwiftUI

/// Full-screen loading view with activity indicator and optional message.
/// Use during language apply / app reload to avoid visual glitches.
struct LoadingScreenView: View {
    /// Optional message below the spinner (e.g. "Applying language…").
    var message: String = L10n("language.applying")
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            AppColorTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.xl) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColorTheme.tabActive))
                    .scaleEffect(1.2 * pulseScale)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }
}

#Preview {
    LoadingScreenView()
}

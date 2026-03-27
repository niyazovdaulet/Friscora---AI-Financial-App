//
//  AppState.swift
//  Friscora
//
//  Root-level app state: drives full view hierarchy reload (e.g. on language change)
//  and shows a full-screen loading overlay during reload to avoid flicker.
//

import SwiftUI
import Combine

/// App-wide state for reload and loading overlay. Injected at root and observed by AppContentView.
final class AppState: ObservableObject {
    
    /// Changing this ID forces SwiftUI to re-create the entire content view hierarchy,
    /// re-applying the new localization from LocalizationManager.
    @Published var rootViewId = UUID()
    
    /// When true, show LoadingScreenView as a full-screen overlay.
    /// Set to true before updating rootViewId, then false after a short delay.
    @Published var isReloading = false
    
    /// Call this after persisting the new language (e.g. LocalizationManager.setLanguage).
    /// Shows loading overlay, bumps rootViewId to reload the app content, then hides overlay.
    func triggerReload() {
        isReloading = true
        
        // Allow one render cycle so the loading view appears.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rootViewId = UUID()
            
            // Brief visible loading so the transition feels intentional.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isReloading = false
            }
        }
    }
}

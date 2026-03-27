//
//  UserProfileService.swift
//  Friscora
//
//  Service for managing user profile data
//

import Foundation
import Combine

/// Service for managing user profile
class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    @Published var profile: UserProfile = UserProfile()
    
    private let profileKey = "user_profile"
    
    private init() {
        loadProfile()
        NotificationCenter.default.addObserver(self, selector: #selector(handleICloudSyncUpdate), name: .ICloudSyncDidUpdate, object: nil)
    }
    
    @objc private func handleICloudSyncUpdate() {
        loadProfile()
    }
    
    /// Load profile from UserDefaults
    func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        } else {
            // First time loading - set installation date
            profile.appInstallationDate = Date()
            saveProfile(profile)
        }
        
        // Backward compatibility: ensure authentication field exists
        // This handles old profiles that don't have isAuthenticationEnabled
        // The Codable will decode it as false if missing, which is fine
    }
    
    /// Save profile to UserDefaults
    func saveProfile(_ profile: UserProfile) {
        self.profile = profile
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    /// Check if onboarding is completed
    var hasCompletedOnboarding: Bool {
        profile.hasCompletedOnboarding
    }
    
    /// Complete onboarding
    func completeOnboarding() {
        profile.hasCompletedOnboarding = true
        saveProfile(profile)
    }
}


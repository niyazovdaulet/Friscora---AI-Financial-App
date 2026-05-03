//
//  AuthenticationService.swift
//  Friscora
//
//  Service for managing authentication (passcode and biometric)
//

import Foundation
import LocalAuthentication
import Security
import Combine

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    private let passcodeKey = "com.friscora.passcode"
    private let biometricEnabledKey = "com.friscora.biometricEnabled"
    
    @Published var isAuthenticated = false
    private var lastBackgroundAt: Date?
    
    private init() {}
    
    // MARK: - Passcode Management
    
    /// Save passcode to Keychain
    func savePasscode(_ passcode: String) -> Bool {
        guard let data = passcode.data(using: .utf8) else { return false }
        
        // Delete existing passcode if any
        deletePasscode()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve passcode from Keychain
    func getPasscode() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let passcode = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return passcode
    }
    
    /// Delete passcode from Keychain
    func deletePasscode() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    /// Check if passcode exists
    var hasPasscode: Bool {
        getPasscode() != nil
    }
    
    /// Verify passcode
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let storedPasscode = getPasscode() else { return false }
        return passcode == storedPasscode
    }
    
    // MARK: - Biometric Management
    
    /// Check if biometric authentication is available
    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get biometric type (FaceID, TouchID, or none)
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }
    
    /// Check if biometric is enabled
    var isBiometricEnabled: Bool {
        UserDefaults.standard.bool(forKey: biometricEnabledKey)
    }
    
    /// Set biometric enabled state
    func setBiometricEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: biometricEnabledKey)
    }
    
    /// Authenticate with biometric
    func authenticateWithBiometric(completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error ?? NSError(domain: "com.friscora.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Biometric authentication not available"]))
            return
        }
        
        let reason = "Authenticate to access Friscora"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    /// Authenticate with passcode or biometric
    func authenticate(completion: @escaping (Bool) -> Void) {
        if isBiometricEnabled && isBiometricAvailable {
            authenticateWithBiometric { [weak self] success, _ in
                if success {
                    self?.isAuthenticated = true
                    completion(true)
                } else {
                    // Fallback to passcode if biometric fails
                    completion(false)
                }
            }
        } else {
            // Passcode authentication will be handled by UI
            completion(false)
        }
    }
    
    /// Clear authentication state
    func clearAuthentication() {
        isAuthenticated = false
        resetResumeTimingState()
    }

    /// Mark that app moved out of active state during this process lifetime.
    func markAppBecameInactive() {
        lastBackgroundAt = Date()
    }

    /// Determines if authentication is needed when app returns to foreground.
    /// - Important: If no in-memory background timestamp exists, treat as cold launch and require auth.
    func shouldRequireAuthenticationOnAppActive(
        securityEnabled: Bool,
        now: Date = Date()
    ) -> Bool {
        guard securityEnabled else {
            return false
        }

        // If user is already unauthenticated, lock should be shown.
        guard isAuthenticated else {
            return true
        }

        // No in-memory timestamp in current process => cold launch (or unsafe state): require auth.
        guard let lastBackgroundAt else {
            isAuthenticated = false
            return true
        }

        let elapsed = now.timeIntervalSince(lastBackgroundAt)

        // Clock skew / manual time changes can create negative intervals; fail closed.
        guard elapsed >= 0 else {
            isAuthenticated = false
            return true
        }

        if elapsed > AppConstants.Security.authGracePeriodSeconds {
            isAuthenticated = false
            return true
        }

        return false
    }

    /// Clears in-memory resume timing; used when security is disabled or auth state is reset.
    func resetResumeTimingState() {
        lastBackgroundAt = nil
    }
    
    /// Disable authentication (requires current authentication)
    func disableAuthentication(completion: @escaping (Bool) -> Void) {
        // First verify with biometric or passcode
        if isBiometricEnabled && isBiometricAvailable {
            authenticateWithBiometric { [weak self] success, _ in
                if success {
                    self?.deletePasscode()
                    self?.setBiometricEnabled(false)
                    completion(true)
                } else {
                    completion(false)
                }
            }
        } else if hasPasscode {
            // Will need to verify passcode in UI
            completion(false)
        } else {
            // No authentication set up
            completion(true)
        }
    }
}


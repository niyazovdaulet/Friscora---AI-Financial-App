//
//  ICloudSyncService.swift
//  Friscora
//
//  Syncs app data to iCloud via NSUbiquitousKeyValueStore so data follows the user across devices.
//

import Foundation
import Combine

/// Notification posted when iCloud has newer data and local UserDefaults was updated. Services should reload their data.
extension Notification.Name {
    static let ICloudSyncDidUpdate = Notification.Name("ICloudSyncDidUpdate")
}

/// Keys we sync to iCloud (must match UserDefaults keys used by services).
private enum SyncKey {
    static let expenses = "saved_expenses"
    static let incomes = "saved_incomes"
    static let goals = "saved_goals"
    static let goalActivities = "saved_goal_activities"
    static let customCategories = "saved_custom_categories"
    static let workDays = "saved_work_days"
    static let jobs = "saved_jobs"
    static let personalScheduleEvents = "saved_personal_schedule_events"
    static let userProfile = "user_profile"
    static let syncTimestamp = "friscora_sync_timestamp"
}

private let syncTimestampLocalKey = "friscora_sync_timestamp_local"

/// Syncs UserDefaults-backed app data to iCloud. Uses last-write-wins: the device that saved most recently wins.
/// Enable iCloud + iCloud Documents (or Key-Value storage) in Signing & Capabilities for the app.
final class ICloudSyncService: ObservableObject {
    static let shared = ICloudSyncService()
    
    private let store = NSUbiquitousKeyValueStore.default
    private let userDefaults = UserDefaults.standard
    
    /// Last time we successfully pushed to iCloud (for UI).
    @Published private(set) var lastSyncedAt: Date?
    
    /// True while a sync (pull or push) is in progress.
    @Published private(set) var isSyncing = false
    
    private let keysToSync: [(String, String)] = [
        (SyncKey.expenses, SyncKey.expenses),
        (SyncKey.incomes, SyncKey.incomes),
        (SyncKey.goals, SyncKey.goals),
        (SyncKey.goalActivities, SyncKey.goalActivities),
        (SyncKey.customCategories, SyncKey.customCategories),
        (SyncKey.workDays, SyncKey.workDays),
        (SyncKey.jobs, SyncKey.jobs),
        (SyncKey.personalScheduleEvents, SyncKey.personalScheduleEvents),
        (SyncKey.userProfile, SyncKey.userProfile)
    ]
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        // First sync from iCloud (async so we don't block launch)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.syncFromCloud()
        }
    }
    
    @objc private func ubiquitousStoreDidChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.syncFromCloud()
        }
    }
    
    /// Pull from iCloud and overwrite local if iCloud is newer. Safe to call from any thread.
    func syncFromCloud() {
        DispatchQueue.main.async { [weak self] in self?.isSyncing = true }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.store.synchronize()
            let cloudTimestamp = self.store.double(forKey: SyncKey.syncTimestamp)
            let localTimestamp = self.userDefaults.double(forKey: syncTimestampLocalKey)
            if cloudTimestamp <= 0 || cloudTimestamp <= localTimestamp {
                DispatchQueue.main.async { [weak self] in self?.isSyncing = false }
                return
            }
            for (udKey, cloudKey) in self.keysToSync {
                if let data = self.store.data(forKey: cloudKey) {
                    self.userDefaults.set(data, forKey: udKey)
                }
            }
            self.userDefaults.set(cloudTimestamp, forKey: syncTimestampLocalKey)
            DispatchQueue.main.async {
                self.isSyncing = false
                NotificationCenter.default.post(name: .ICloudSyncDidUpdate, object: nil)
            }
        }
    }
    
    /// Push current UserDefaults to iCloud. Safe to call from any thread; work runs in background.
    func syncToCloud() {
        DispatchQueue.main.async { [weak self] in self?.isSyncing = true }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let timestamp = Date().timeIntervalSince1970
            for (udKey, cloudKey) in self.keysToSync {
                if let data = self.userDefaults.data(forKey: udKey) {
                    self.store.set(data, forKey: cloudKey)
                }
            }
            self.store.set(timestamp, forKey: SyncKey.syncTimestamp)
            _ = self.store.synchronize()
            self.userDefaults.set(timestamp, forKey: syncTimestampLocalKey)
            DispatchQueue.main.async { [weak self] in
                self?.lastSyncedAt = Date()
                self?.isSyncing = false
            }
        }
    }
}

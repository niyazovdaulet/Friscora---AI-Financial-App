//
//  NotificationService.swift
//  Friscora
//
//  Service for managing local notifications
//

import Foundation
import UserNotifications
import Combine

struct NotificationSchedule: Codable, Equatable {
    var morningEnabled: Bool
    var morningTime: Date // Time component only
    var eveningEnabled: Bool
    var eveningTime: Date // Time component only
    var customEnabled: Bool
    var customTime: Date? // Time component only
    
    init(morningEnabled: Bool = true,
         morningTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date(),
         eveningEnabled: Bool = true,
         eveningTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date(),
         customEnabled: Bool = false,
         customTime: Date? = nil) {
        self.morningEnabled = morningEnabled
        self.morningTime = morningTime
        self.eveningEnabled = eveningEnabled
        self.eveningTime = eveningTime
        self.customEnabled = customEnabled
        self.customTime = customTime
    }
}

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private let scheduleKey = "com.friscora.notificationSchedule"
    
    private init() {
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Schedule Management
    
    func getSchedule() -> NotificationSchedule {
        if let data = UserDefaults.standard.data(forKey: scheduleKey),
           let schedule = try? JSONDecoder().decode(NotificationSchedule.self, from: data) {
            return schedule
        }
        return NotificationSchedule()
    }
    
    func saveSchedule(_ schedule: NotificationSchedule) {
        if let encoded = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(encoded, forKey: scheduleKey)
            scheduleNotifications(schedule)
        }
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleNotifications(_ schedule: NotificationSchedule) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let calendar = Calendar.current
        
        // Morning notification
        if schedule.morningEnabled {
            let components = calendar.dateComponents([.hour, .minute], from: schedule.morningTime)
            scheduleDailyNotification(
                identifier: "morning_reminder",
                title: "Good Morning! 🌅",
                body: "Start your day by tracking your finances",
                hour: components.hour ?? 10,
                minute: components.minute ?? 0
            )
        }
        
        // Evening notification
        if schedule.eveningEnabled {
            let components = calendar.dateComponents([.hour, .minute], from: schedule.eveningTime)
            scheduleDailyNotification(
                identifier: "evening_reminder",
                title: "Evening Check-in 🌙",
                body: "Review your spending for today",
                hour: components.hour ?? 22,
                minute: components.minute ?? 0
            )
        }
        
        // Custom notification
        if schedule.customEnabled, let customTime = schedule.customTime {
            let components = calendar.dateComponents([.hour, .minute], from: customTime)
            scheduleDailyNotification(
                identifier: "custom_reminder",
                title: "Friscora Reminder 📊",
                body: "Time to check your finances",
                hour: components.hour ?? 12,
                minute: components.minute ?? 0
            )
        }
    }
    
    private func scheduleDailyNotification(identifier: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}


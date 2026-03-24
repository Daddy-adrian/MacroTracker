import Foundation
import UserNotifications
internal import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    print("Notifications authorized.")
                } else if let error = error {
                    print("Error requesting notifications authorization: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Water reminders every 3 hours from 9 AM to 9 PM (9:00, 12:00, 15:00, 18:00, 21:00)
    func scheduleWaterReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["Water9", "Water12", "Water15", "Water18", "Water21"])
        
        let hours = [9, 12, 15, 18, 21]
        for hour in hours {
            let content = UNMutableNotificationContent()
            content.title = "Hydration Check 💧"
            content.body = "It's time to drink some water! Stay hydrated for your macros to work."
            content.sound = .default
            
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "Water\(hour)", content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling water reminder for \(hour): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func removeWaterReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["Water9", "Water12", "Water15", "Water18", "Water21"])
    }
    
    // Pre-workout reminder 1 hour before selected workout time
    func schedulePreWorkoutReminder(for workoutTime: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["PreWorkoutMeal"])
        
        let calendar = Calendar.current
        guard let mealTime = calendar.date(byAdding: .hour, value: -1, to: workoutTime) else { return }
        
        let components = calendar.dateComponents([.hour, .minute], from: mealTime)
        
        let content = UNMutableNotificationContent()
        content.title = "Pre-Workout Fuel 🍌"
        content.body = "Time for your pre-workout meal! Grab a banana, oats, or a protein shake to fuel up."
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "PreWorkoutMeal", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling pre-workout reminder: \(error.localizedDescription)")
            }
        }
    }
    
    func removePreWorkoutReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["PreWorkoutMeal"])
    }
    
    // Inactivity reminder if no food is logged for 6 hours
    func resetInactivityReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["NoFood6Hours"])
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Eat! 🍽️"
        content.body = "You haven't logged any food in 6 hours. Make sure you are hitting your macros!"
        content.sound = .default
        
        // 6 hours * 60 minutes * 60 seconds = 21600 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 21600, repeats: false)
        let request = UNNotificationRequest(identifier: "NoFood6Hours", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling inactivity reminder: \(error.localizedDescription)")
            } else {
                print("Scheduled new 6-hour inactivity reminder.")
            }
        }
    }
    
    func removeInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["NoFood6Hours"])
    }
    
    func removeAllScheduledNotifications() {
        removeWaterReminders()
        removePreWorkoutReminder()
        removeInactivityReminder()
    }
}

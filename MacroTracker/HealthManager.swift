import SwiftUI
import Foundation
internal import Combine
import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    
    @Published var dailySteps: Double = 0
    @Published var dailyActiveCalories: Double = 0
    
    init() {
        // Automatically request authorization exactly when the manager is first initialized by the SwiftUI view wrapper
        requestAuthorization()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }
        
        let typesToRead: Set = [stepType, calorieType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                self.fetchTodayData()
            }
        }
    }
    
    func fetchTodayData() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // Fetch Steps
        let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else { return }
            DispatchQueue.main.async {
                self.dailySteps = sum.doubleValue(for: HKUnit.count())
            }
        }
        
        // Fetch Calories
        let calorieQuery = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else { return }
            DispatchQueue.main.async {
                self.dailyActiveCalories = sum.doubleValue(for: HKUnit.kilocalorie())
            }
        }
        
        healthStore.execute(stepQuery)
        healthStore.execute(calorieQuery)
    }
}

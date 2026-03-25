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
                // 1. Fetch immediately on success
                self.fetchTodayData()
                
                // 2. Set up the observers to keep data live
                self.setupBackgroundObserver()
            }
        }
    }
    
    // MARK: - Live Data Observers
    private func setupBackgroundObserver() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let calorieType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        // Enable Background Delivery (Tells iOS to wake the app up if there's new data)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
        healthStore.enableBackgroundDelivery(for: calorieType, frequency: .hourly) { _, _ in }
        
        // Set up the Observer Query for Steps
        let stepObserver = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            if error == nil {
                // New data found! Fetch the latest numbers
                DispatchQueue.main.async {
                    self?.fetchTodayData()
                }
            }
            // Required: Tell HealthKit we are done processing the background event
            completionHandler()
        }
        
        // Set up the Observer Query for Calories
        let calorieObserver = HKObserverQuery(sampleType: calorieType, predicate: nil) { [weak self] _, completionHandler, error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.fetchTodayData()
                }
            }
            completionHandler()
        }
        
        // Execute the listeners
        healthStore.execute(stepObserver)
        healthStore.execute(calorieObserver)
    }
    
    // MARK: - Fetch Logic
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

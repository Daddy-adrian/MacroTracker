import SwiftUI
import Foundation
internal import Combine
import HealthKit
import CoreMotion // <-- NEW: Apple's hardware motion framework

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    let pedometer = CMPedometer() // <-- NEW: Reads the iPhone's hardware directly
    
    @Published var dailySteps: Double = 0
    @Published var dailyActiveCalories: Double = 0
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        // We only need HealthKit for calories now, steps are handled by the hardware
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        healthStore.requestAuthorization(toShare: nil, read: [calorieType]) { success, _ in
            if success {
                self.fetchTodayData()
                self.setupBackgroundObserver()
            }
        }
    }
    
    // MARK: - Live Data Observers
    private func setupBackgroundObserver() {
        // 1. Keep HealthKit observer for Calories
        guard let calorieType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        healthStore.enableBackgroundDelivery(for: calorieType, frequency: .hourly) { _, _ in }
        let calorieObserver = HKObserverQuery(sampleType: calorieType, predicate: nil) { [weak self] _, completionHandler, error in
            if error == nil {
                DispatchQueue.main.async { self?.fetchTodayData() }
            }
            completionHandler()
        }
        healthStore.execute(calorieObserver)
        
        // 2. NEW: Start live hardware step tracking
        startLiveStepTracking()
    }
    
    // MARK: - Fetch Logic
    func fetchTodayData() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // 1. Fetch Calories from HealthKit
        if let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            let calorieQuery = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else { return }
                DispatchQueue.main.async {
                    self.dailyActiveCalories = sum.doubleValue(for: HKUnit.kilocalorie())
                }
            }
            healthStore.execute(calorieQuery)
        }
        
        // 2. Fetch Steps instantly from iPhone Hardware (Bypasses HealthKit delays)
        if CMPedometer.isStepCountingAvailable() {
            pedometer.queryPedometerData(from: startOfDay, to: now) { data, error in
                if let data = data, error == nil {
                    DispatchQueue.main.async {
                        self.dailySteps = data.numberOfSteps.doubleValue
                    }
                }
            }
        }
    }
    
    private func startLiveStepTracking() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        if CMPedometer.isStepCountingAvailable() {
            // This listens to your steps in real-time while the app is open
            pedometer.startUpdates(from: startOfDay) { data, error in
                if let data = data, error == nil {
                    DispatchQueue.main.async {
                        self.dailySteps = data.numberOfSteps.doubleValue
                    }
                }
            }
        }
    }
}

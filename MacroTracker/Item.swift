//
//  Item.swift  (Repurposed as Models)
//  MacroTracker
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var weightKg: Double
    var heightCm: Double
    var age: Int
    var isMale: Bool
    var goal: String // "cut", "maintain", "mass"
    var activityLevel: Double // 1.2 to 1.9

    // New properties
    var smartNotificationsEnabled: Bool = false
    var usualWorkoutTime: Date?

    // Calculated Targets
    var bmr: Double
    var targetCalories: Double
    var targetProtein: Double
    
    init(weightKg: Double, heightCm: Double, age: Int, isMale: Bool = true, goal: String, activityLevel: Double, targetCalories: Double, targetProtein: Double, smartNotificationsEnabled: Bool = false, usualWorkoutTime: Date? = nil) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.age = age
        self.isMale = isMale
        self.goal = goal
        self.activityLevel = activityLevel
        
        // Mifflin-St Jeor Equation
        let weightFactor = 10.0 * weightKg
        let heightFactor = 6.25 * heightCm
        let ageFactor = 5.0 * Double(age)
        self.bmr = weightFactor + heightFactor - ageFactor + (isMale ? 5.0 : -161.0)
        
        self.targetCalories = targetCalories
        self.targetProtein = targetProtein
        
        self.smartNotificationsEnabled = smartNotificationsEnabled
        self.usualWorkoutTime = usualWorkoutTime
    }
}

@Model
final class FoodItem {
    var name: String
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double
    var caloriesPer100g: Double
    
    var unitName: String
    var unitWeightGrams: Double
    
    var dailyGoalAmount: Double = 0.0
    
    init(name: String, proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double, fiberPer100g: Double, caloriesPer100g: Double, unitName: String = "100g", unitWeightGrams: Double = 100.0, dailyGoalAmount: Double = 0.0) {
        self.name = name
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.caloriesPer100g = caloriesPer100g
        self.unitName = unitName
        self.unitWeightGrams = unitWeightGrams
        self.dailyGoalAmount = dailyGoalAmount
    }
}

@Model
final class DailyEntry {
    var timestamp: Date
    var foodItem: FoodItem?
    var isAdHoc: Bool
    var adHocName: String
    
    var consumedGrams: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var calories: Double
    
    init(timestamp: Date = Date(), foodItem: FoodItem? = nil, isAdHoc: Bool = false, adHocName: String = "", consumedGrams: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0, fiber: Double = 0, calories: Double = 0) {
        self.timestamp = timestamp
        self.foodItem = foodItem
        self.isAdHoc = isAdHoc
        self.adHocName = adHocName
        self.consumedGrams = consumedGrams
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.calories = calories
    }
}

@Model
final class DailyHistory {
    var dateSaved: Date
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var totalFiber: Double
    var containsAdHoc: Bool
    
    init(dateSaved: Date = Date(), totalCalories: Double = 0, totalProtein: Double = 0, totalCarbs: Double = 0, totalFat: Double = 0, totalFiber: Double = 0, containsAdHoc: Bool = false) {
        self.dateSaved = dateSaved
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
        self.totalFiber = totalFiber
        self.containsAdHoc = containsAdHoc
    }
}

@Model
final class WorkoutEntry {
    var timestamp: Date
    var caloriesBurned: Double
    
    init(timestamp: Date = Date(), caloriesBurned: Double = 250.0) {
        self.timestamp = timestamp
        self.caloriesBurned = caloriesBurned
    }
}

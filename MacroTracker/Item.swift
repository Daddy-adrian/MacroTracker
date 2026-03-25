import Foundation
import SwiftData

@Model
final class UserProfile {
    var weightKg: Double
    var heightCm: Double
    var age: Int
    var isMale: Bool
    var goal: String
    var activityLevel: Double
    var smartNotificationsEnabled: Bool = false
    var usualWorkoutTime: Date?
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

// MARK: - Database Seeder Logic
struct DatabaseSeeder {
    @MainActor
    static func seed(context: ModelContext) {
        // Only seed if the food list is empty to prevent duplicates
        let descriptor = FetchDescriptor<FoodItem>()
        if let existing = try? context.fetch(descriptor), existing.isEmpty {
            let menu = [
                FoodItem(name: "Cheese", proteinPer100g: 30, carbsPer100g: 0, fatPer100g: 9, fiberPer100g: 0, caloriesPer100g: 200, unitName: "slice", unitWeightGrams: 30, dailyGoalAmount: 5),
                FoodItem(name: "Veggie Salad", proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 10, fiberPer100g: 8, caloriesPer100g: 150, unitName: "salad", unitWeightGrams: 100, dailyGoalAmount: 1),
                FoodItem(name: "Tahini", proteinPer100g: 21, carbsPer100g: 3, fatPer100g: 56, fiberPer100g: 5, caloriesPer100g: 634, unitName: "spoon", unitWeightGrams: 20, dailyGoalAmount: 1),
                FoodItem(name: "Meat", proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 4.3, fiberPer100g: 0, caloriesPer100g: 200, unitName: "100gr", unitWeightGrams: 100, dailyGoalAmount: 3),
                FoodItem(name: "Yams", proteinPer100g: 2, carbsPer100g: 21, fatPer100g: 0.15, fiberPer100g: 3.3, caloriesPer100g: 100, unitName: "100gr", unitWeightGrams: 100, dailyGoalAmount: 2),
                FoodItem(name: "Eggs", proteinPer100g: 7, carbsPer100g: 0.65, fatPer100g: 6.15, fiberPer100g: 0, caloriesPer100g: 90, unitName: "egg", unitWeightGrams: 100, dailyGoalAmount: 2),
                FoodItem(name: "Green Beans", proteinPer100g: 3, carbsPer100g: 3, fatPer100g: 0, fiberPer100g: 3, caloriesPer100g: 30, unitName: "100gr", unitWeightGrams: 100, dailyGoalAmount: 4),
                FoodItem(name: "Frozen Berries", proteinPer100g: 1.3, carbsPer100g: 7.5, fatPer100g: 0, fiberPer100g: 1.3, caloriesPer100g: 50, unitName: "100gr", unitWeightGrams: 100, dailyGoalAmount: 3),
                FoodItem(name: "Pro Bread", proteinPer100g: 27, carbsPer100g: 13, fatPer100g: 3.5, fiberPer100g: 12.3, caloriesPer100g: 220, unitName: "slice", unitWeightGrams: 30, dailyGoalAmount: 1),
                FoodItem(name: "Apple", proteinPer100g: 0, carbsPer100g: 26, fatPer100g: 0.3, fiberPer100g: 4.5, caloriesPer100g: 90, unitName: "fruit", unitWeightGrams: 100, dailyGoalAmount: 0),
                FoodItem(name: "Cheeseburger", proteinPer100g: 27, carbsPer100g: 30, fatPer100g: 16.2, fiberPer100g: 0, caloriesPer100g: 379, unitName: "burger", unitWeightGrams: 100, dailyGoalAmount: 0),
                FoodItem(name: "McDonalds Fries", proteinPer100g: 5, carbsPer100g: 34, fatPer100g: 15.2, fiberPer100g: 0, caloriesPer100g: 294, unitName: "fries", unitWeightGrams: 100, dailyGoalAmount: 0),
                FoodItem(name: "Protein Chips", proteinPer100g: 20, carbsPer100g: 5, fatPer100g: 4.5, fiberPer100g: 1, caloriesPer100g: 140, unitName: "snack", unitWeightGrams: 100, dailyGoalAmount: 0)
            ]
            for item in menu {
                context.insert(item)
            }
            try? context.save()
        }
    }
}

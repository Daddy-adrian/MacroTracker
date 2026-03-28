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

// MARK: - Database Seeder Logic (Updated Table)
// MARK: - Database Seeder Logic (Final Corrected Values)
struct DatabaseSeeder {
    @MainActor
    static func seed(context: ModelContext) {
        // בודק אם הרשימה ריקה כדי למנוע כפילויות בכל הרצה
        let descriptor = FetchDescriptor<FoodItem>()
        if let existing = try? context.fetch(descriptor), existing.isEmpty {
            let menu = [
                FoodItem(name: "טחינה מלאה", proteinPer100g: 22.0, carbsPer100g: 3.0, fatPer100g: 56.0, fiberPer100g: 15.0, caloriesPer100g: 631.0, unitName: "כף", unitWeightGrams: 15.0, dailyGoalAmount: 3.0),
                
                FoodItem(name: "גבינה צהובה", proteinPer100g: 30.0, carbsPer100g: 0.2, fatPer100g: 9.0, fiberPer100g: 0.0, caloriesPer100g: 202.0, unitName: "פרוסה", unitWeightGrams: 30.0, dailyGoalAmount: 3.0),
                
                FoodItem(name: "שייטל (בקר)", proteinPer100g: 22.0, carbsPer100g: 0.0, fatPer100g: 4.2, fiberPer100g: 0.0, caloriesPer100g: 200.0, unitName: "100גר", unitWeightGrams: 100.0, dailyGoalAmount: 2.0),
                
                FoodItem(name: "כבד עוף", proteinPer100g: 25.0, carbsPer100g: 0.9, fatPer100g: 6.5, fiberPer100g: 0.0, caloriesPer100g: 170.0, unitName: "100גר", unitWeightGrams: 100.0, dailyGoalAmount: 1.5),
                
                FoodItem(name: "ביצה קשה", proteinPer100g: 12.5, carbsPer100g: 1.12, fatPer100g: 10.6, fiberPer100g: 0.0, caloriesPer100g: 155.0, unitName: "ביצה", unitWeightGrams: 70.0, dailyGoalAmount: 3.0),
                
                FoodItem(name: "שעועית ירוקה", proteinPer100g: 2.0, carbsPer100g: 1.0, fatPer100g: 0.5, fiberPer100g: 2.2, caloriesPer100g: 29.0, unitName: "100גר", unitWeightGrams: 100.0, dailyGoalAmount: 5.0),
                
                FoodItem(name: "פירות יער קפואים", proteinPer100g: 1.3, carbsPer100g: 3.8, fatPer100g: 0.0, fiberPer100g: 3.8, caloriesPer100g: 45.0, unitName: "100גר", unitWeightGrams: 100.0, dailyGoalAmount: 2.0),
                
                FoodItem(name: "שמן זית", proteinPer100g: 0.0, carbsPer100g: 0.0, fatPer100g: 100.0, fiberPer100g: 0.0, caloriesPer100g: 1000.0, unitName: "כף", unitWeightGrams: 10.0, dailyGoalAmount: 2.0)
            ]
            
            for item in menu {
                context.insert(item)
            }
            
            do {
                try context.save()
                print("✅ Database successfully seeded with Adrian's custom menu.")
            } catch {
                print("❌ Failed to seed database: \(error.localizedDescription)")
            }
        }
    }
}

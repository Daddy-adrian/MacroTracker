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
    
    var unitName: String = ""
    var unitWeight: Double = 100.0
    var dailyGoal: Double?
    
    init(name: String, proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double, fiberPer100g: Double, caloriesPer100g: Double, unitName: String = "", unitWeight: Double = 100.0, dailyGoal: Double? = nil) {
        self.name = name
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.caloriesPer100g = caloriesPer100g
        self.unitName = unitName
        self.unitWeight = unitWeight
        self.dailyGoal = dailyGoal
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
    var name: String
    var caloriesBurned: Double
    
    init(timestamp: Date = Date(), name: String = "Main Workout", caloriesBurned: Double = 250.0) {
        self.timestamp = timestamp
        self.name = name
        self.caloriesBurned = caloriesBurned
    }
}

// MARK: - Smart Database Sync Logic

struct DatabaseSeeder {
    @MainActor
    static func seed(context: ModelContext) {
        // 1. Fetch current items in storage
        let descriptor = FetchDescriptor<FoodItem>()
        let existingItems = (try? context.fetch(descriptor)) ?? []
        
        // 2. Define the target menu from your latest spreadsheet (16 items)
        let latestMenu = [
            FoodItem(name: "טחינה מלאה", proteinPer100g: 22.0, carbsPer100g: 3.0, fatPer100g: 56.0, fiberPer100g: 15.0, caloriesPer100g: 631.0, unitName: "כף", unitWeight: 15.0),
            FoodItem(name: "גבינה צהובה", proteinPer100g: 30.0, carbsPer100g: 0.2, fatPer100g: 9.0, fiberPer100g: 0.0, caloriesPer100g: 202.0, unitName: "פרוסה", unitWeight: 30.0, dailyGoal: 5.0),
            FoodItem(name: "בשר/דג", proteinPer100g: 22.0, carbsPer100g: 0.0, fatPer100g: 4.28, fiberPer100g: 0.0, caloriesPer100g: 200.0),
            FoodItem(name: "לחם פרו", proteinPer100g: 28.0, carbsPer100g: 13.0, fatPer100g: 3.4, fiberPer100g: 12.3, caloriesPer100g: 220.0, unitName: "פרוסה", unitWeight: 30.0),
            FoodItem(name: "ביצה קשה", proteinPer100g: 7.0, carbsPer100g: 0.65, fatPer100g: 6.1, fiberPer100g: 0.0, caloriesPer100g: 90.0, unitName: "יחידה", unitWeight: 50.0),
            FoodItem(name: "הרינג", proteinPer100g: 14.0, carbsPer100g: 0.0, fatPer100g: 12.0, fiberPer100g: 0.0, caloriesPer100g: 170.0),
            FoodItem(name: "פירות יער קפואים", proteinPer100g: 1.3, carbsPer100g: 5.0, fatPer100g: 0.0, fiberPer100g: 3.8, caloriesPer100g: 45.0, unitName: "גביע", unitWeight: 100.0),
            FoodItem(name: "שעועית ירוקה", proteinPer100g: 2.1, carbsPer100g: 7.0, fatPer100g: 0.0, fiberPer100g: 3.0, caloriesPer100g: 34.0),
            FoodItem(name: "פרי", proteinPer100g: 0.0, carbsPer100g: 25.0, fatPer100g: 0.0, fiberPer100g: 4.0, caloriesPer100g: 100.0, unitName: "יחידה", unitWeight: 150.0),
            FoodItem(name: "אבוקדו", proteinPer100g: 2.0, carbsPer100g: 8.5, fatPer100g: 14.5, fiberPer100g: 6.7, caloriesPer100g: 160.0),
            FoodItem(name: "אפונה קפואה", proteinPer100g: 5.7, carbsPer100g: 7.0, fatPer100g: 0.0, fiberPer100g: 5.0, caloriesPer100g: 71.0),
            FoodItem(name: "פסטרמה", proteinPer100g: 15.0, carbsPer100g: 6.0, fatPer100g: 3.0, fiberPer100g: 0.0, caloriesPer100g: 111.0, unitName: "פרוסה", unitWeight: 20.0),
            FoodItem(name: "בטטה", proteinPer100g: 2.0, carbsPer100g: 21.0, fatPer100g: 0.0, fiberPer100g: 3.3, caloriesPer100g: 90.0),
            FoodItem(name: "אורז", proteinPer100g: 3.0, carbsPer100g: 26.0, fatPer100g: 0.0, fiberPer100g: 0.0, caloriesPer100g: 120.0),
            FoodItem(name: "אגוזים", proteinPer100g: 15.0, carbsPer100g: 14.0, fatPer100g: 65.0, fiberPer100g: 6.7, caloriesPer100g: 654.0),
            FoodItem(name: "חטיף חלבון", proteinPer100g: 20.0, carbsPer100g: 3.0, fatPer100g: 4.5, fiberPer100g: 1.0, caloriesPer100g: 140.0, unitName: "חטיף", unitWeight: 60.0)
        ]
        
        // 3. Sync Logic: Update existing or Insert new
        for newItem in latestMenu {
            if let existing = existingItems.first(where: { $0.name == newItem.name }) {
                // Update nutrition values
                existing.proteinPer100g = newItem.proteinPer100g
                existing.carbsPer100g = newItem.carbsPer100g
                existing.fatPer100g = newItem.fatPer100g
                existing.fiberPer100g = newItem.fiberPer100g
                existing.caloriesPer100g = newItem.caloriesPer100g
                
                // Allow sync to override units
                if existing.unitName.isEmpty && !newItem.unitName.isEmpty {
                    existing.unitName = newItem.unitName
                    existing.unitWeight = newItem.unitWeight
                }
                if existing.dailyGoal == nil {
                    existing.dailyGoal = newItem.dailyGoal
                }
            } else {
                // Item doesn't exist, insert it
                context.insert(newItem)
            }
        }
        
        // 4. Save changes
        do {
            try context.save()
            print("✅ Database successfully synced with all 16 food items from the menu.")
        } catch {
            print("❌ Failed to sync database: \(error.localizedDescription)")
        }
    }
}

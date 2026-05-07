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
    var waistCm: Double?
    var bmr: Double
    var targetCalories: Double
    var targetProtein: Double
    
    func syncToCloud() {
        let store = NSUbiquitousKeyValueStore.default
        store.set(weightKg, forKey: "bk_weight")
        store.set(heightCm, forKey: "bk_height")
        store.set(Int64(age), forKey: "bk_age")
        store.set(isMale, forKey: "bk_isMale")
        store.set(goal, forKey: "bk_goal")
        store.set(activityLevel, forKey: "bk_activity")
        store.set(waistCm ?? 0, forKey: "bk_waist")
        store.set(targetCalories, forKey: "bk_targetCalories")
        store.set(targetProtein, forKey: "bk_targetProtein")
        store.synchronize()
    }
    
    init(weightKg: Double, heightCm: Double, age: Int, isMale: Bool = true, goal: String, activityLevel: Double, targetCalories: Double, targetProtein: Double, smartNotificationsEnabled: Bool = false, usualWorkoutTime: Date? = nil, waistCm: Double? = nil) {
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
        self.waistCm = waistCm
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
final class BodyMetricsLog {
    var date: Date
    var weightKg: Double
    var waistCm: Double?
    
    init(date: Date = Date(), weightKg: Double, waistCm: Double? = nil) {
        self.date = date
        self.weightKg = weightKg
        self.waistCm = waistCm
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

// MARK: - Smart Database Sync Logic (Strict Daily Goals)

struct DatabaseSeeder {
    @MainActor
    static func seed(context: ModelContext) {
        let descriptor = FetchDescriptor<FoodItem>()
        let existingItems = (try? context.fetch(descriptor)) ?? []
        
        let latestMenu = [
            // מאכלים עם כמות יומית מוגדרת (התפריט שלך)
            FoodItem(name: "טחינה מלאה", proteinPer100g: 22.0, carbsPer100g: 3.0, fatPer100g: 56.0, fiberPer100g: 15.0, caloriesPer100g: 631.0, unitName: "כף", unitWeight: 15.0, dailyGoal: 2.0),
            FoodItem(name: "ריקוטה למריחה", proteinPer100g: 6.0, carbsPer100g: 3.0, fatPer100g: 5.0, fiberPer100g: 3.0, caloriesPer100g: 90.0, unitName: "חבילה", unitWeight: 200.0, dailyGoal: 1.0),
            FoodItem(name: "בשר/דג", proteinPer100g: 22.0, carbsPer100g: 0.0, fatPer100g: 4.28, fiberPer100g: 0.0, caloriesPer100g: 200.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: 3.0),
            FoodItem(name: "לחם פרו", proteinPer100g: 28.0, carbsPer100g: 13.0, fatPer100g: 3.4, fiberPer100g: 12.3, caloriesPer100g: 220.0, unitName: "פרוסה", unitWeight: 30.0, dailyGoal: 2.0),
            FoodItem(name: "ביצה קשה", proteinPer100g: 7.0, carbsPer100g: 0.65, fatPer100g: 6.1, fiberPer100g: 0.0, caloriesPer100g: 90.0, unitName: "יחידה", unitWeight: 100.0, dailyGoal: 2.0),
            FoodItem(name: "פירות יער קפואים", proteinPer100g: 1.3, carbsPer100g: 5.0, fatPer100g: 0.0, fiberPer100g: 3.8, caloriesPer100g: 45.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: 3.0),
            FoodItem(name: "שעועית ירוקה", proteinPer100g: 2.1, carbsPer100g: 7.0, fatPer100g: 0.0, fiberPer100g: 3.0, caloriesPer100g: 34.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: 4.0),
            FoodItem(name: "Omega 3 & Creatine", proteinPer100g: 0.0, carbsPer100g: 0.0, fatPer100g: 0.0, fiberPer100g: 0.0, caloriesPer100g: 0.0, unitName: "pill", unitWeight: 1.0, dailyGoal: 1.0),
            FoodItem(name: "אפונה קפואה", proteinPer100g: 5.2, carbsPer100g: 12.8, fatPer100g: 0.0, fiberPer100g: 4.7, caloriesPer100g: 60.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: 4.0),
            
            // מאכלים במאגר ללא כמות יומית (dailyGoal: nil)
            FoodItem(name: "בורגול", proteinPer100g: 3.0, carbsPer100g: 18.0, fatPer100g: 0.0, fiberPer100g: 4.5, caloriesPer100g: 85.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: nil),
            FoodItem(name: "גבינה צהובה", proteinPer100g: 30.0, carbsPer100g: 0.2, fatPer100g: 9.0, fiberPer100g: 0.0, caloriesPer100g: 202.0, unitName: "פרוסה", unitWeight: 30.0, dailyGoal: 0.0),
            FoodItem(name: "עדשים כתומות", proteinPer100g: 8.0, carbsPer100g: 20.0, fatPer100g: 0.0, fiberPer100g: 8.0, caloriesPer100g: 120.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: 0.0),
            FoodItem(name: "בטטה", proteinPer100g: 2.0, carbsPer100g: 21.0, fatPer100g: 0.0, fiberPer100g: 3.3, caloriesPer100g: 90.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: 0.0),
            FoodItem(name: "הרינג", proteinPer100g: 14.0, carbsPer100g: 0.0, fatPer100g: 12.0, fiberPer100g: 0.0, caloriesPer100g: 170.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: nil),
            FoodItem(name: "פרי", proteinPer100g: 0.0, carbsPer100g: 25.0, fatPer100g: 0.0, fiberPer100g: 4.0, caloriesPer100g: 100.0, unitName: "יחידה", unitWeight: 100.0, dailyGoal: nil),
            FoodItem(name: "אבוקדו", proteinPer100g: 2.0, carbsPer100g: 8.5, fatPer100g: 14.5, fiberPer100g: 6.7, caloriesPer100g: 160.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: nil),
            FoodItem(name: "פסטרמה", proteinPer100g: 15.0, carbsPer100g: 6.0, fatPer100g: 3.0, fiberPer100g: 0.0, caloriesPer100g: 111.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: nil),
            FoodItem(name: "אורז", proteinPer100g: 3.0, carbsPer100g: 26.0, fatPer100g: 0.0, fiberPer100g: 0.0, caloriesPer100g: 120.0, unitName: "100 גרם", unitWeight: 100.0, dailyGoal: nil),
            FoodItem(name: "אגוזים", proteinPer100g: 15.0, carbsPer100g: 14.0, fatPer100g: 65.0, fiberPer100g: 6.7, caloriesPer100g: 654.0, unitName: "יחידה", unitWeight: 8.0, dailyGoal: nil),
            FoodItem(name: "חטיף חלבון", proteinPer100g: 20.0, carbsPer100g: 3.0, fatPer100g: 4.5, fiberPer100g: 1.0, caloriesPer100g: 140.0, unitName: "יחידה", unitWeight: 100.0, dailyGoal: nil),
            FoodItem(name: "טריפל בורגר",proteinPer100g: 38.0,carbsPer100g: 31.0,fatPer100g: 23.5,fiberPer100g: 0.0,caloriesPer100g: 490.0,unitName: "יחידה",unitWeight: 100.0,dailyGoal: nil),
            FoodItem(name: "ציפס",proteinPer100g: 5.0,carbsPer100g: 34.0,fatPer100g: 15.2,fiberPer100g: 0.0,caloriesPer100g: 294.0,unitName: "יחידה",unitWeight: 100.0,dailyGoal: nil)
        ]
        
        for newItem in latestMenu {
            if let _ = existingItems.first(where: { $0.name == newItem.name }) {
                // Item already exists. We do NOTHING so we preserve any changes the user made manually.
            } else {
                context.insert(newItem)
            }
        }
        
        try? context.save()
    }
}

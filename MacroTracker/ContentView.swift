//
//  ContentView.swift
//  MacroTracker
//

import SwiftUI
import SwiftData

// MARK: - Theme & Styling
extension Color {
    static let pastelBackground = Color(hex: "C5D5C8") // soft Green
    static let pastelCard = Color.white
    static let pastelText = Color(hex: "2b2d42")
    static let pastelTextMuted = Color(hex: "6c7a89")
    
    static let macroCalories = Color(hex: "76c893")
    static let macroProtein = Color(hex: "ffb5a7")
    static let macroProteinText = Color(hex: "d63031")
    static let macroCaloriesText = Color(hex: "00b894") // Vivid Deep Green
    static let macroCarbs = Color(hex: "a8dadc")
    static let macroFats = Color(hex: "b3d89c")
    static let macroFiber = Color(hex: "81c784") // A soft teal/green for fiber
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct SoftCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.pastelCard)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
    }
}

extension View {
    func softCardStyle() -> some View {
        self.modifier(SoftCardStyle())
    }
}

// MARK: - Components
struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "f0f3f5"), lineWidth: lineWidth)
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
    }
}

struct ProgressBarView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: "f0f3f5"))
                RoundedRectangle(cornerRadius: 5)
                    .fill(color)
                    .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width))
                    .animation(.easeInOut(duration: 0.8), value: progress)
            }
        }
        .frame(height: 10)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(profile: profile)
            } else {
                SetupView()
            }
        }
        .preferredColorScheme(.light) // Fixes Dark Mode text invisibility
    }
}

struct MainTabView: View {
    var profile: UserProfile
    
    var body: some View {
        TabView {
            HomeView(profile: profile)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
            
            CalorieCalculatorView(profile: profile)
                .tabItem {
                    Label("Calculator", systemImage: "flame.fill")
                }
            
            FoodDatabaseView()
                .tabItem {
                    Label("My Foods", systemImage: "list.bullet.clipboard")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            SettingsWrapperView(profile: profile)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(Color.macroCalories)
        .fontWeight(.medium)
        .font(.system(.body, design: .rounded))
    }
}

struct SettingsWrapperView: View {
    var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            SetupView(existingProfile: profile)
                .navigationTitle("Update Profile")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Erase All Data", role: .destructive) {
                            deleteAllData()
                        }
                        .foregroundColor(.red)
                    }
                }
        }
    }
    
    private func deleteAllData() {
        do {
            try modelContext.delete(model: UserProfile.self)
            try modelContext.delete(model: FoodItem.self)
            try modelContext.delete(model: DailyEntry.self)
            try modelContext.delete(model: DailyHistory.self)
            try modelContext.delete(model: WorkoutEntry.self)
            try modelContext.save()
        } catch {}
    }
}

// MARK: - Setup / Profile View
struct SetupView: View {
    @Environment(\.modelContext) private var modelContext
    var existingProfile: UserProfile?
    
    @State private var weightStr = ""
    @State private var heightStr = ""
    @State private var ageStr = ""
    @State private var isMale = true
    
    @State private var goal = "Maintain"
    let goals = ["Cut", "Maintain", "Mass"]
    
    @State private var activityLevel = 1.2
    let activityLevels: [(String, Double)] = [
        ("Sedentary", 1.2),
        ("Lightly Active", 1.375),
        ("Moderately Active", 1.55),
        ("Very Active", 1.725)
    ]
    
    @State private var manualCalories: Double = 0
    @State private var manualProtein: Double = 0
    @State private var hasEditedSliders = false
    @State private var showingSavedAlert = false
    
    @State private var smartNotificationsEnabled = false
    @State private var usualWorkoutTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    
    var weight: Double { Double(weightStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var height: Double { Double(heightStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var age: Int { Int(ageStr) ?? 0 }
    
    var bmr: Double {
        if weight > 0 && height > 0 && age > 0 {
            return (10.0 * weight) + (6.25 * height) - (5.0 * Double(age)) + (isMale ? 5.0 : -161.0)
        }
        return 0
    }
    
    var tdee: Double { bmr * activityLevel }
    
    var defaultCalories: Double {
        switch goal {
        case "Cut": return tdee - 300
        case "Mass": return tdee + 500
        default: return tdee
        }
    }
    
    var minimumProtein: Double { weight * 0.8 }
    
    var defaultProtein: Double {
        switch goal {
        case "Cut": return weight * 1.7
        case "Maintain": return weight * 1.6
        case "Mass": return weight * 1.5
        default: return weight * 1.6
        }
    }
    
    var displayCalories: Double {
        hasEditedSliders ? manualCalories : max(defaultCalories, bmr)
    }
    
    var displayProtein: Double {
        hasEditedSliders ? manualProtein : max(defaultProtein, minimumProtein)
    }
    
    var isFormValid: Bool { weight > 0 && height > 0 && age > 0 }

    var body: some View {
        Group {
            if existingProfile == nil {
                NavigationView { formContent.navigationTitle("Setup Profile") }
            } else {
                formContent
            }
        }
        .onAppear { loadExisting() }
    }
    
    var formContent: some View {
        Form {
            Section(header: Text("Physical Specs (Metric)")) {
                Picker("Biological Sex", selection: $isMale) {
                    Text("Male").tag(true)
                    Text("Female").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                TextField("Weight (kg)", text: $weightStr).keyboardType(.decimalPad)
                TextField("Height (cm)", text: $heightStr).keyboardType(.decimalPad)
                TextField("Age", text: $ageStr).keyboardType(.numberPad)
            }
            .listRowBackground(Color.pastelCard)
            
            Section(header: Text("Lifestyle & Goal")) {
                Picker("Goal", selection: $goal) {
                    ForEach(goals, id: \.self) { Text($0) }
                }
                Picker("Activity", selection: $activityLevel) {
                    ForEach(activityLevels, id: \.1) { level in
                        Text(level.0).tag(level.1)
                    }
                }
            }
            .listRowBackground(Color.pastelCard)
            
            Section(header: Text("Smart Reminders (Water, Food, Pre-Workout)")) {
                Toggle("Enable Smart Reminders", isOn: $smartNotificationsEnabled)
                if smartNotificationsEnabled {
                    DatePicker("Usual Workout Time", selection: $usualWorkoutTime, displayedComponents: .hourAndMinute)
                }
            }
            .listRowBackground(Color.pastelCard)
            
            if isFormValid {
                Section(header: Text("Calculations")) {
                    HStack { Text("BMR"); Spacer(); Text("\(Int(bmr)) kcal") }
                    HStack { Text("TDEE"); Spacer(); Text("\(Int(tdee)) kcal") }
                }
                .listRowBackground(Color.pastelCard)
                
                Section(header: Text("Daily Targets"), footer: Text("Adjust your targets. Manual tweaks are saved until you reset them.")) {
                    VStack(alignment: .leading) {
                        Text("Calories: \(Int(displayCalories)) kcal")
                        Slider(
                            value: Binding(
                                get: { self.displayCalories },
                                set: { newValue in
                                    if !self.hasEditedSliders {
                                        self.manualProtein = self.displayProtein
                                    }
                                    self.manualCalories = newValue
                                    self.hasEditedSliders = true
                                }
                            ),
                            in: bmr...max(bmr + 1, 5000),
                            step: 10
                        )
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Protein: \(Int(displayProtein)) g")
                        Slider(
                            value: Binding(
                                get: { self.displayProtein },
                                set: { newValue in
                                    if !self.hasEditedSliders {
                                        self.manualCalories = self.displayCalories
                                    }
                                    self.manualProtein = newValue
                                    self.hasEditedSliders = true
                                }
                            ),
                            in: minimumProtein...max(minimumProtein + 1, 400),
                            step: 1
                        )
                    }
                    
                    // Allow the user to reset to BMR calculations if they want
                    if hasEditedSliders {
                        Button("Reset to Recommended") {
                            hasEditedSliders = false
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .listRowBackground(Color.pastelCard)
                
                Button(action: {
                    saveProfile()
                    if existingProfile != nil { showingSavedAlert = true }
                }) {
                    Text(existingProfile == nil ? "Save & Continue" : "Update Profile")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.macroCalories)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                }
                .listRowBackground(Color.clear)
                .alert("Profile Updated Successfully!", isPresented: $showingSavedAlert) {
                    Button("OK", role: .cancel) { }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
    }
    
    private func loadExisting() {
        if let profile = existingProfile {
            weightStr = String(format: "%.1f", profile.weightKg)
            heightStr = String(format: "%.1f", profile.heightCm)
            ageStr = "\(profile.age)"
            isMale = profile.isMale
            goal = profile.goal
            activityLevel = profile.activityLevel
            
            // Set sliders to saved state and lock them there
            manualCalories = profile.targetCalories
            manualProtein = profile.targetProtein
            hasEditedSliders = true
            
            smartNotificationsEnabled = profile.smartNotificationsEnabled
            if let wTime = profile.usualWorkoutTime {
                usualWorkoutTime = wTime
            }
        }
    }
    
    private func saveProfile() {
        if let profile = existingProfile {
            profile.weightKg = weight
            profile.heightCm = height
            profile.age = age
            profile.isMale = isMale
            profile.goal = goal
            profile.activityLevel = activityLevel
            profile.targetCalories = displayCalories
            profile.targetProtein = displayProtein
            profile.smartNotificationsEnabled = smartNotificationsEnabled
            profile.usualWorkoutTime = usualWorkoutTime
        } else {
            let profile = UserProfile(
                weightKg: weight,
                heightCm: height,
                age: age,
                isMale: isMale,
                goal: goal,
                activityLevel: activityLevel,
                targetCalories: displayCalories,
                targetProtein: displayProtein,
                smartNotificationsEnabled: smartNotificationsEnabled,
                usualWorkoutTime: usualWorkoutTime
            )
            modelContext.insert(profile)
        }
        try? modelContext.save()
    }
}

// MARK: - Food Database Views
struct FoodDatabaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foodDatabase: [FoodItem]
    @State private var showingAddFoodMenu = false
    @State private var foodToEdit: FoodItem?
    
    var body: some View {
        NavigationView {
            List {
                if foodDatabase.isEmpty {
                    Text("No foods in your menu yet. Add some!")
                        .foregroundColor(.gray)
                        .listRowBackground(Color.pastelCard)
                }
                ForEach(foodDatabase) { food in
                    Button(action: { foodToEdit = food }) {
                        VStack(alignment: .leading) {
                            Text(food.name).font(.headline)
                                .foregroundColor(Color.pastelText)
                            Text("\(Int(food.caloriesPer100g)) kcal | \(Int(food.proteinPer100g))p | \(Int(food.carbsPer100g))c | \(Int(food.fatPer100g))f per 100g")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    )
                    .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(foodDatabase[index])
                    }
                    try? modelContext.save()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("My Foods")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        ImportMenuButton() // Your new modular import feature!
                        
                        Button(action: { showingAddFoodMenu = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddFoodMenu) {
                FoodMenuEntryView(existingFood: nil)
            }
            .sheet(item: $foodToEdit) { food in
                FoodMenuEntryView(existingFood: food)
            }
        }
    }
}

struct FoodMenuEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var existingFood: FoodItem?
    
    @State private var name: String = ""
    @State private var proteinStr = ""
    @State private var carbsStr = ""
    @State private var fatStr = ""
    @State private var fiberStr = ""
    @State private var caloriesStr = ""
    
    @State private var unitName: String = ""
    @State private var unitWeightStr: String = ""
    @State private var dailyGoalStr: String = ""
    
    var isFormValid: Bool {
        !name.isEmpty && !proteinStr.isEmpty && !caloriesStr.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Name")) {
                    TextField("E.g., Tahini, Chicken, Rice", text: $name)
                }
                .listRowBackground(Color.white)
                
                Section(header: Text("Macros per 100g")) {
                    ZStack(alignment: .leading) { Text("Calories (kcal)").allowsHitTesting(false); TextField("0", text: $caloriesStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Protein (g)").allowsHitTesting(false); TextField("0", text: $proteinStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Carbs (g)").allowsHitTesting(false); TextField("0", text: $carbsStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Fat (g)").allowsHitTesting(false); TextField("0", text: $fatStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Fiber (g)").allowsHitTesting(false); TextField("0", text: $fiberStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                }
                .listRowBackground(Color.white)
                
                Section(header: Text("Unit & Tracking (Optional)")) {
                    TextField("Unit Name (e.g., slice, spoon)", text: $unitName)
                    ZStack(alignment: .leading) { Text("Unit Weight (g)").allowsHitTesting(false); TextField("100", text: $unitWeightStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Daily Goal (units)").allowsHitTesting(false); TextField("Optional", text: $dailyGoalStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                }
                .listRowBackground(Color.white)
            }
            .scrollContentBackground(.hidden)
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(existingFood == nil ? "Add Food" : "Edit Food")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() }.bold().foregroundColor(Color.macroProteinText),
                trailing: Button("Save") { saveFood() }.bold().disabled(!isFormValid).foregroundColor(isFormValid ? Color.macroCaloriesText : .gray)
            )
        }
        .onAppear { loadExisting() }
    }
    
    private func loadExisting() {
        if let food = existingFood {
            name = food.name
            proteinStr = "\(food.proteinPer100g)"
            carbsStr = "\(food.carbsPer100g)"
            fatStr = "\(food.fatPer100g)"
            fiberStr = "\(food.fiberPer100g)"
            caloriesStr = "\(food.caloriesPer100g)"
            unitName = food.unitName
            unitWeightStr = "\(food.unitWeight)"
            if let goal = food.dailyGoal {
                dailyGoalStr = "\(goal)"
            }
        }
    }
    
    private func saveFood() {
        let cleanProtein = Double(proteinStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanCarbs = Double(carbsStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanFat = Double(fatStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanFiber = Double(fiberStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanCalories = Double(caloriesStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        let targetUnitWeight = Double(unitWeightStr.replacingOccurrences(of: ",", with: ".")) ?? 100.0
        let targetGoal = Double(dailyGoalStr.replacingOccurrences(of: ",", with: "."))
        
        if let food = existingFood {
            food.name = name
            food.proteinPer100g = cleanProtein
            food.carbsPer100g = cleanCarbs
            food.fatPer100g = cleanFat
            food.fiberPer100g = cleanFiber
            food.caloriesPer100g = cleanCalories
            food.unitName = unitName
            food.unitWeight = targetUnitWeight
            food.dailyGoal = targetGoal
        } else {
            let food = FoodItem(
                name: name,
                proteinPer100g: cleanProtein,
                carbsPer100g: cleanCarbs,
                fatPer100g: cleanFat,
                fiberPer100g: cleanFiber,
                caloriesPer100g: cleanCalories,
                unitName: unitName,
                unitWeight: targetUnitWeight,
                dailyGoal: targetGoal
            )
            modelContext.insert(food)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Dashboard Views
struct GoalTrackerRow: View {
    @Environment(\.modelContext) private var modelContext
    var food: FoodItem
    var consumed: Double
    
    @State private var inputStr: String = "1"
    
    var body: some View {
        HStack {
            Text("\(food.name): \(consumed, specifier: "%g") / \(food.dailyGoal ?? 0, specifier: "%g") \(food.unitName)")
                .font(.subheadline)
                .foregroundColor(Color.pastelText)
            
            Spacer()
            
            TextField("1", text: $inputStr)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50)
            
            Button(action: logManualUnits) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color.macroCalories)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private func logManualUnits() {
        let cleanInputStr = inputStr.replacingOccurrences(of: ",", with: ".")
        let unitsToLog = Double(cleanInputStr) ?? 1.0
        
        let targetUnitWeight = max(1.0, food.unitWeight)
        let totalGrams = unitsToLog * targetUnitWeight
        let multiplier = totalGrams / 100.0
        
        let entry = DailyEntry(
            timestamp: Date(),
            foodItem: food,
            isAdHoc: false,
            consumedGrams: totalGrams,
            protein: food.proteinPer100g * multiplier,
            carbs: food.carbsPer100g * multiplier,
            fat: food.fatPer100g * multiplier,
            fiber: food.fiberPer100g * multiplier,
            calories: food.caloriesPer100g * multiplier
        )
        withAnimation {
            modelContext.insert(entry)
            try? modelContext.save()
        }
        
        inputStr = "1"
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    var profile: UserProfile
    
    @Query(sort: \DailyEntry.timestamp, order: .reverse) private var allEntries: [DailyEntry]
    @Query(sort: \FoodItem.name) private var foodDatabase: [FoodItem]
    
    @State private var showingAdHocMenu = false
    
    @State private var selectedFood: FoodItem?
    @State private var gramsToLogStr = "100"
    
    @State private var adHocName = ""
    @State private var adHocProteinStr = ""
    @State private var adHocCaloriesStr = ""
    
    var todayEntries: [DailyEntry] {
        allEntries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    var consumedCalories: Double { todayEntries.reduce(0) { $0 + $1.calories } }
    var consumedProtein: Double { todayEntries.reduce(0) { $0 + $1.protein } }
    var consumedCarbs: Double { todayEntries.reduce(0) { $0 + $1.carbs } }
    var consumedFat: Double { todayEntries.reduce(0) { $0 + $1.fat } }
    var consumedFiber: Double { todayEntries.reduce(0) { $0 + $1.fiber } }
    
    var hasAdHoc: Bool { todayEntries.contains { $0.isAdHoc } }
    
    var activeGoalFoods: [FoodItem] {
        foodDatabase.filter { food in
            if let goal = food.dailyGoal, goal > 0 {
                let units = unitsConsumed(for: food)
                return units < Double(goal)
            }
            return false
        }
    }
    
    func unitsConsumed(for food: FoodItem) -> Double {
        let consumedGrams = todayEntries.filter { $0.foodItem == food }.reduce(0) { $0 + $1.consumedGrams }
        return consumedGrams / max(1.0, food.unitWeight)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    VStack(spacing: 16) {
                        HStack(alignment: .top) {
                            Text("Today's Summary")
                                .font(.headline)
                                .foregroundColor(Color.pastelText)
                            Spacer()
                            if hasAdHoc {
                                Text("⚠️ Appx")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        VStack(spacing: 4) {
                            HStack {
                                Text("Calories 🔥")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.pastelText)
                                Spacer()
                                Text("\(Int(consumedCalories)) / \(Int(profile.targetCalories)) kcal")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.pastelTextMuted)
                            }
                            ProgressBarView(progress: consumedCalories / max(1, profile.targetCalories), color: Color.macroCalories)
                        }
                        
                        VStack(spacing: 4) {
                            HStack {
                                Text("Protein 🥩")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.pastelText)
                                Spacer()
                                Text("\(Int(consumedProtein)) / \(Int(profile.targetProtein))g")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.pastelTextMuted)
                            }
                            ProgressBarView(progress: consumedProtein / max(1, profile.targetProtein), color: Color.macroProtein)
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("P: \(Int(consumedProtein))g")
                                    .foregroundColor(Color.macroProtein)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("C: \(Int(consumedCarbs))g")
                                    .foregroundColor(Color.macroCarbs)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("F: \(Int(consumedFat))g")
                                    .foregroundColor(Color.macroFats)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Fib: \(Int(consumedFiber))g")
                                    .foregroundColor(Color.macroFiber)
                            }
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .softCardStyle()
                    .padding(.horizontal)
                    
                    if !activeGoalFoods.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Goals Tracker")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(activeGoalFoods) { food in
                                GoalTrackerRow(food: food, consumed: unitsConsumed(for: food))
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Log Food")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if showingAdHocMenu {
                            VStack {
                                TextField("Food Name (Temporary)", text: $adHocName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                HStack {
                                    TextField("Calories", text: $adHocCaloriesStr).keyboardType(.decimalPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    TextField("Protein (g)", text: $adHocProteinStr).keyboardType(.decimalPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                HStack {
                                    Button("Cancel") { withAnimation { showingAdHocMenu = false } }
                                        .bold()
                                        .foregroundColor(Color.macroProteinText)
                                    Spacer()
                                    Button(action: { logAdHocFood() }) {
                                        Text("Log Temporary Item")
                                            .font(.body.bold())
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.macroCalories)
                                }
                            }
                            .softCardStyle()
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                Picker("Select Food", selection: $selectedFood) {
                                    Text("Choose a food...").tag(nil as FoodItem?)
                                    ForEach(foodDatabase) { food in
                                        Text(food.name).tag(food as FoodItem?)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity)
                                .background(Color.pastelCard)
                                .cornerRadius(12)
                                .softCardStyle()
                                .onChange(of: selectedFood) { _, newValue in
                                    if let newSelected = newValue {
                                        gramsToLogStr = newSelected.unitName.isEmpty ? "100" : "1"
                                    }
                                }
                                
                                if let selected = selectedFood {
                                    HStack {
                                        Text(selected.unitName.isEmpty ? "Grams:" : "\(selected.unitName):")
                                            .font(.subheadline.bold())
                                        TextField(selected.unitName.isEmpty ? "100" : "1", text: $gramsToLogStr)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 80)
                                        
                                        Spacer()
                                        
                                        Button(action: logSelectedFood) {
                                            Text("Log \(selected.name)")
                                                .font(.body.bold())
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(Color.macroCalories)
                                                .foregroundColor(.white)
                                                .cornerRadius(12)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Button(action: {
                            withAnimation { showingAdHocMenu = true }
                        }) {
                            HStack {
                                Image(systemName: "plus.app.fill")
                                Text("Outside of Menu Food")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.pastelTextMuted.opacity(0.15))
                            .foregroundColor(Color.pastelText)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 5)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Logs")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if todayEntries.isEmpty {
                            Text("No items logged yet today.")
                                .padding(.horizontal)
                                .foregroundColor(Color.pastelTextMuted)
                        }
                        
                        ForEach(todayEntries) { entry in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.isAdHoc ? entry.adHocName : (entry.foodItem?.name ?? "Unknown"))
                                        .font(.footnote).bold()
                                        .foregroundColor(Color.pastelText)
                                    if !entry.isAdHoc {
                                        Text("\(entry.consumedGrams, specifier: "%.1f")g")
                                            .font(.caption2)
                                            .foregroundColor(Color.pastelTextMuted)
                                    }
                                }
                                Spacer()
                                Text("P \(Int(entry.protein)) C \(Int(entry.calories))")
                                    .font(.caption2)
                                    .foregroundColor(Color.pastelTextMuted)
                                
                                Button(role: .destructive) {
                                    withAnimation {
                                        modelContext.delete(entry)
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.macroProteinText)
                                        .font(.title3.bold())
                                }
                                .padding(.leading, 4)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.pastelCard)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                    
                    Button(action: saveAndResetDay) {
                        Text("Save & Reset Day")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.macroCaloriesText)
                            .foregroundColor(.white)
                            .cornerRadius(24)
                    }
                    .padding()
                }
                .padding(.vertical)
            }
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
        }
    }
    
    private func logQuickUnit(for food: FoodItem) {
        let totalGrams = max(1.0, food.unitWeight)
        let multiplier = totalGrams / 100.0
        
        let entry = DailyEntry(
            timestamp: Date(),
            foodItem: food,
            isAdHoc: false,
            consumedGrams: totalGrams,
            protein: food.proteinPer100g * multiplier,
            carbs: food.carbsPer100g * multiplier,
            fat: food.fatPer100g * multiplier,
            fiber: food.fiberPer100g * multiplier,
            calories: food.caloriesPer100g * multiplier
        )
        withAnimation {
            modelContext.insert(entry)
            try? modelContext.save()
        }
    }

    private func logSelectedFood() {
        guard let food = selectedFood else { return }
        
        let inputStr = gramsToLogStr.replacingOccurrences(of: ",", with: ".")
        let inputVal = Double(inputStr) ?? (food.unitName.isEmpty ? 100.0 : 1.0)
        let targetUnitWeight = food.unitName.isEmpty ? 100.0 : food.unitWeight
        let totalGrams = food.unitName.isEmpty ? inputVal : inputVal * targetUnitWeight
        
        let multiplier = totalGrams / 100.0
        
        let entry = DailyEntry(
            timestamp: Date(),
            foodItem: food,
            isAdHoc: false,
            consumedGrams: totalGrams,
            protein: food.proteinPer100g * multiplier,
            carbs: food.carbsPer100g * multiplier,
            fat: food.fatPer100g * multiplier,
            fiber: food.fiberPer100g * multiplier,
            calories: food.caloriesPer100g * multiplier
        )
        withAnimation {
            modelContext.insert(entry)
            try? modelContext.save()
        }
        
        selectedFood = nil
        gramsToLogStr = "100"
    }
    
    private func logAdHocFood() {
        let cleanCals = Double(adHocCaloriesStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanPro = Double(adHocProteinStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        guard !adHocName.isEmpty else { return }
        
        let entry = DailyEntry(
            timestamp: Date(),
            isAdHoc: true,
            adHocName: adHocName,
            protein: cleanPro,
            calories: cleanCals
        )
        withAnimation {
            modelContext.insert(entry)
            try? modelContext.save()
        }
        
        adHocName = ""
        adHocCaloriesStr = ""
        adHocProteinStr = ""
        withAnimation { showingAdHocMenu = false }
    }
    
    private func saveAndResetDay() {
        guard !todayEntries.isEmpty else { return }
        
        let history = DailyHistory(
            dateSaved: Date(),
            totalCalories: consumedCalories,
            totalProtein: consumedProtein,
            totalCarbs: consumedCarbs,
            totalFat: consumedFat,
            totalFiber: consumedFiber,
            containsAdHoc: hasAdHoc
        )
        modelContext.insert(history)
        
        for entry in todayEntries {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

struct HistoryView: View {
    @Query(sort: \DailyHistory.dateSaved, order: .reverse) private var histories: [DailyHistory]
    
    var body: some View {
        NavigationView {
            List {
                if histories.isEmpty {
                    Text("No history logs yet.")
                        .foregroundColor(.gray)
                        .listRowBackground(Color.pastelCard)
                }
                ForEach(histories) { history in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(history.dateSaved, style: .date).font(.headline)
                        HStack {
                            Text("\(Int(history.totalCalories)) kcal")
                            Spacer()
                            Text("\(Int(history.totalProtein))g Protein")
                        }
                        .font(.subheadline)
                        HStack {
                            Text("\(Int(history.totalCarbs))g C")
                            Spacer()
                            Text("\(Int(history.totalFat))g F")
                            Spacer()
                            Text("\(Int(history.totalFiber))g Fib.")
                        }
                        .font(.caption).foregroundColor(.gray)
                        if history.containsAdHoc {
                            Text("⚠️ Appx metrics (contained out-of-menu items)")
                                .font(.caption2).foregroundColor(.red)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    )
                    .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("History")
        }
    }
}


struct CalorieCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) var scenePhase
    var profile: UserProfile
    @StateObject private var healthManager = HealthManager()
    
    @Query(sort: \DailyEntry.timestamp, order: .reverse) private var allEntries: [DailyEntry]
    @Query(sort: \WorkoutEntry.timestamp, order: .reverse) private var workouts: [WorkoutEntry]
    
    var todayEntries: [DailyEntry] {
        allEntries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    var todayWorkouts: [WorkoutEntry] {
        workouts.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    var hasMainWorkout: Bool {
        todayWorkouts.contains { $0.name == "Main Workout" }
    }
    
    var hasSwingsClimbers: Bool {
        todayWorkouts.contains { $0.name == "Swings & Climbers" }
    }
    
    var consumedCalories: Double { todayEntries.reduce(0) { $0 + $1.calories } }
    var sedentaryBurned: Double { -(profile.bmr * 1.2) }
    var stepsBurned: Double { -(healthManager.dailySteps * 0.04) }
    var workoutsBurned: Double { -todayWorkouts.reduce(0) { $0 + $1.caloriesBurned } }
    var netCalories: Double { consumedCalories + sedentaryBurned + stepsBurned + workoutsBurned }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Net Calorie Balance").font(.headline).foregroundColor(Color.pastelTextMuted)
                        Text(String(format: "%+.0f kcal", netCalories))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(netCalories > 0 ? Color.macroProteinText : Color.macroCaloriesText)
                        Text(netCalories > 0 ? "You are currently in a surplus." : "You are currently in a deficit.")
                            .font(.subheadline).foregroundColor(Color.pastelTextMuted)
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Calorie Breakdown").font(.headline.bold()).foregroundColor(Color.pastelText)
                        VStack(spacing: 12) {
                            HStack { Text("🔥 Sedentary Burn"); Spacer(); Text(String(format: "%.0f kcal", sedentaryBurned)).foregroundColor(.gray) }
                            HStack { Text("👟 Steps (\(Int(healthManager.dailySteps)))"); Spacer(); Text(String(format: "%.0f kcal", stepsBurned)).foregroundColor(.gray) }
                            HStack { Text("💪 Workouts (\(todayWorkouts.count))"); Spacer(); Text(String(format: "%.0f kcal", workoutsBurned)).foregroundColor(.gray) }
                            HStack { Text("🍔 Food Consumed"); Spacer(); Text(String(format: "+%.0f kcal", consumedCalories)).foregroundColor(.green) }
                            Divider()
                            HStack { Text("Net Total").bold(); Spacer(); Text(String(format: "%+.0f kcal", netCalories)).bold().foregroundColor(netCalories > 0 ? Color.macroProteinText : Color.macroCaloriesText) }
                        }
                    }
                    .softCardStyle()
                    .padding(.horizontal)
                    
                    // NEW: Toggle Button Logic
                    VStack(spacing: 12) {
                        Button(action: { toggleWorkout(name: "Main Workout", calories: 250.0) }) {
                            Text(hasMainWorkout ? "Main Workout ✅ (Tap to Undo)" : "Complete Workout (-250 kcal)")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(hasMainWorkout ? Color.macroCaloriesText.opacity(0.8) : Color.macroCalories)
                                .foregroundColor(.white)
                                .cornerRadius(24)
                        }
                        
                        Button(action: { toggleWorkout(name: "Swings & Climbers", calories: 150.0) }) {
                            Text(hasSwingsClimbers ? "Swings & Climbers ✅ (Tap to Undo)" : "Swings & Climbers (-150 kcal)")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(hasSwingsClimbers ? Color.macroCaloriesText.opacity(0.8) : Color(hex: "48cae4"))
                                .foregroundColor(.white)
                                .cornerRadius(24)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("Calculator")
            .onAppear { healthManager.fetchTodayData() }
            .onChange(of: scenePhase) { _, newPhase in if newPhase == .active { healthManager.fetchTodayData() } }
        }
    }
    
    // NEW: Function to handle both adding and undoing
    private func toggleWorkout(name: String, calories: Double) {
        withAnimation {
            if let existing = todayWorkouts.first(where: { $0.name == name }) {
                modelContext.delete(existing)
            } else {
                let entry = WorkoutEntry(timestamp: Date(), name: name, caloriesBurned: calories)
                modelContext.insert(entry)
            }
            try? modelContext.save()
        }
    }
}

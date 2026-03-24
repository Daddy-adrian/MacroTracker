//
//  ContentView.swift
//  MacroTracker
//

import SwiftUI
import SwiftData

// MARK: - Theme & Styling
extension Color {
    static let pastelBackground = Color(hex: "fdfaf6")
    static let pastelCard = Color.white
    static let pastelText = Color(hex: "2b2d42")
    static let pastelTextMuted = Color(hex: "6c7a89") // Deepened slate for better contrast
    
    static let macroCalories = Color(hex: "76c893")
    static let macroProtein = Color(hex: "ffb5a7")
    static let macroProteinText = Color(hex: "d63031") // deep red for text contrast
    static let macroCaloriesText = Color(hex: "00b894") // deep green for text contrast
    static let macroCarbs = Color(hex: "a8dadc")
    static let macroFats = Color(hex: "b3d89c")
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
        if let profile = profiles.first {
            MainTabView(profile: profile)
        } else {
            SetupView()
        }
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
        .fontWeight(.medium) // Global bolding for all text within the app
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
            try modelContext.save()
        } catch {}
    }
}

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
        .onChange(of: goal) { _ in hasEditedSliders = false }
        .onChange(of: activityLevel) { _ in hasEditedSliders = false }
        .onChange(of: weightStr) { _ in hasEditedSliders = false }
        .onChange(of: heightStr) { _ in hasEditedSliders = false }
        .onChange(of: ageStr) { _ in hasEditedSliders = false }
        .onChange(of: isMale) { _ in hasEditedSliders = false }
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
            
            if isFormValid {
                Section(header: Text("Calculations")) {
                    HStack { Text("BMR"); Spacer(); Text("\(Int(bmr)) kcal") }
                    HStack { Text("TDEE"); Spacer(); Text("\(Int(tdee)) kcal") }
                }
                
                Section(header: Text("Daily Targets"), footer: Text("Adjust your targets. Calories cannot fall below BMR (\(Int(bmr))). Protein cannot fall below \(Int(minimumProtein))g.")) {
                    VStack(alignment: .leading) {
                        Text("Calories: \(Int(displayCalories)) kcal")
                        Slider(
                            value: Binding(
                                get: { self.displayCalories },
                                set: { newValue in
                                    if !self.hasEditedSliders {
                                        self.manualProtein = self.displayProtein
                                        self.hasEditedSliders = true
                                    }
                                    self.manualCalories = newValue
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
                                        self.hasEditedSliders = true
                                    }
                                    self.manualProtein = newValue
                                }
                            ),
                            in: minimumProtein...max(minimumProtein + 1, 400),
                            step: 1
                        )
                    }
                }
                
                Button(action: {
                    saveProfile()
                    if existingProfile != nil { showingSavedAlert = true }
                }) {
                    Text(existingProfile == nil ? "Save & Continue" : "Update Profile")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.macroCalories) // Save/Update is Green
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
            manualCalories = profile.targetCalories
            manualProtein = profile.targetProtein
            hasEditedSliders = true
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
        } else {
            let profile = UserProfile(
                weightKg: weight,
                heightCm: height,
                age: age,
                isMale: isMale,
                goal: goal,
                activityLevel: activityLevel,
                targetCalories: displayCalories,
                targetProtein: displayProtein
            )
            modelContext.insert(profile)
        }
        try? modelContext.save()
    }
}

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
                }
                ForEach(foodDatabase) { food in
                    Button(action: { foodToEdit = food }) {
                        VStack(alignment: .leading) {
                            Text(food.name).font(.headline)
                                .foregroundColor(Color.pastelText)
                            Text("\(Int(food.caloriesPer100g)) kcal | \(Int(food.proteinPer100g))g P per 100g")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Custom Unit: \(food.unitName) (\(Int(food.unitWeightGrams))g)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
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
                    Button(action: { showingAddFoodMenu = true }) {
                        Image(systemName: "plus")
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
    
    @State private var unitName = ""
    @State private var unitWeightGramsStr = ""
    @State private var dailyGoalStr = ""
    
    var isFormValid: Bool {
        !name.isEmpty && !proteinStr.isEmpty && !caloriesStr.isEmpty && !unitName.isEmpty && !unitWeightGramsStr.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Name")) {
                    TextField("E.g., Tahini, Chicken, Rice", text: $name)
                }
                
                Section(header: Text("Macros per 100g")) {
                    ZStack(alignment: .leading) { Text("Calories (kcal)").allowsHitTesting(false); TextField("0", text: $caloriesStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Protein (g)").allowsHitTesting(false); TextField("0", text: $proteinStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Carbs (g)").allowsHitTesting(false); TextField("0", text: $carbsStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Fat (g)").allowsHitTesting(false); TextField("0", text: $fatStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    ZStack(alignment: .leading) { Text("Fiber (g)").allowsHitTesting(false); TextField("0", text: $fiberStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                }
                
                Section(header: Text("Custom Measurement Unit"), footer: Text("Specify how you prefer to measure this food.")) {
                    ZStack(alignment: .leading) { Text("Unit").allowsHitTesting(false); TextField("e.g. 1 spoon", text: $unitName).multilineTextAlignment(.trailing) }
                    ZStack(alignment: .leading) { Text("Weight (grams)").allowsHitTesting(false); TextField("e.g. 20", text: $unitWeightGramsStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                }
                
                Section(header: Text("Daily Goal (Optional)"), footer: Text("Set how many units you want to eat every day.")) {
                    ZStack(alignment: .leading) { Text("Goal Amount").allowsHitTesting(false); TextField("e.g. 4", text: $dailyGoalStr).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                }
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
            unitWeightGramsStr = "\(food.unitWeightGrams)"
            
            if food.dailyGoalAmount > 0 {
                dailyGoalStr = "\(food.dailyGoalAmount)"
            }
        }
    }
    
    private func saveFood() {
        let cleanProtein = Double(proteinStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanCarbs = Double(carbsStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanFat = Double(fatStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanFiber = Double(fiberStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanCalories = Double(caloriesStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanUnitWeight = Double(unitWeightGramsStr.replacingOccurrences(of: ",", with: ".")) ?? 100
        let cleanGoalAmount = Double(dailyGoalStr.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        
        if let food = existingFood {
            food.name = name
            food.proteinPer100g = cleanProtein
            food.carbsPer100g = cleanCarbs
            food.fatPer100g = cleanFat
            food.fiberPer100g = cleanFiber
            food.caloriesPer100g = cleanCalories
            food.unitName = unitName
            food.unitWeightGrams = cleanUnitWeight
            food.dailyGoalAmount = cleanGoalAmount
        } else {
            let food = FoodItem(
                name: name,
                proteinPer100g: cleanProtein,
                carbsPer100g: cleanCarbs,
                fatPer100g: cleanFat,
                fiberPer100g: cleanFiber,
                caloriesPer100g: cleanCalories,
                unitName: unitName,
                unitWeightGrams: cleanUnitWeight,
                dailyGoalAmount: cleanGoalAmount
            )
            modelContext.insert(food)
        }
        try? modelContext.save()
        dismiss()
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    var profile: UserProfile
    @StateObject private var healthManager = HealthManager()
    
    @Query(sort: \DailyEntry.timestamp, order: .reverse) private var allEntries: [DailyEntry]
    @Query(sort: \FoodItem.name) private var foodDatabase: [FoodItem]
    
    @State private var showingAdHocMenu = false
    
    @State private var searchText = ""
    @State private var selectedFood: FoodItem?
    @State private var amountToLogStr = "1"
    
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
    
    var totalMacros: Double { consumedProtein + consumedCarbs + consumedFat }
    var proteinPct: Double { totalMacros > 0 ? (consumedProtein / totalMacros) * 100 : 0 }
    var carbsPct: Double { totalMacros > 0 ? (consumedCarbs / totalMacros) * 100 : 0 }
    var fatPct: Double { totalMacros > 0 ? (consumedFat / totalMacros) * 100 : 0 }
    
    // Time-based sedentary calories burned up to the current moment in the day
    var sedentaryBurnedSoFar: Double {
        let sedentaryTDEE = profile.bmr * 1.2
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let secondsPassed = now.timeIntervalSince(startOfDay)
        let fractionOfDay = secondsPassed / (24 * 60 * 60)
        return sedentaryTDEE * fractionOfDay
    }
    
    // Ongoing Caloric Status Formula
    var currentCalorieBalance: Double {
        return consumedCalories - (sedentaryBurnedSoFar + healthManager.dailyActiveCalories)
    }
    
    var searchResults: [FoodItem] {
        let baseItems = foodDatabase.filter { food in
            if food.dailyGoalAmount <= 0 { return true }
            let consumed = todayEntries.filter { $0.foodItem == food }.reduce(0.0) { $0 + ($1.consumedGrams / food.unitWeightGrams) }
            return consumed >= food.dailyGoalAmount
        }
        if searchText.isEmpty { return baseItems }
        return baseItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var goalFoods: [FoodItem] {
        foodDatabase.filter { food in
            if food.dailyGoalAmount <= 0 { return false }
            let consumed = todayEntries.filter { $0.foodItem == food }.reduce(0.0) { $0 + ($1.consumedGrams / food.unitWeightGrams) }
            return consumed < food.dailyGoalAmount
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Real-Time Calorie Status Hero
                    let balance = currentCalorieBalance
                    
                    VStack(spacing: 8) {
                        Text("Current Balance")
                            .font(.headline)
                            .foregroundColor(Color.pastelTextMuted)
                        
                        Text(String(format: "%+d kcal", Int(balance)))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(balance > 0 ? Color.macroProteinText : Color.macroCaloriesText)
                        
                        Text(balance > 0 ? "You are currently in a surplus." : "You are currently in a deficit.")
                            .font(.subheadline)
                            .foregroundColor(Color.pastelTextMuted)
                    }
                    .padding(.top, 10)
                    
                    // HealthKit Activity Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Today's Activity")
                                .font(.headline.bold())
                                .foregroundColor(Color.pastelText)
                            Spacer()
                            Image(systemName: "heart.fill")
                                .foregroundColor(Color.macroProtein)
                        }
                        
                        HStack(spacing: 16) {
                            // Steps Card
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .foregroundColor(Color.pastelText)
                                    Text("Steps")
                                        .font(.caption)
                                        .foregroundColor(Color.pastelTextMuted)
                                }
                                Text("\(Int(healthManager.dailySteps))")
                                    .font(.title2.bold())
                                    .foregroundColor(Color.pastelText)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.pastelCard)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                            
                            // Active Energy Card
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(Color.macroFats)
                                    Text("Burned")
                                        .font(.caption)
                                        .foregroundColor(Color.pastelTextMuted)
                                }
                                Text("\(Int(healthManager.dailyActiveCalories)) kcal")
                                    .font(.title2.bold())
                                    .foregroundColor(Color.pastelText)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.pastelCard)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Progress Dashboard
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
                        
                        // Calories
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
                        
                        // Protein
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
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // Percentages
                        HStack {
                            Text("Prot: \(Int(proteinPct))%")
                                .foregroundColor(Color.macroProtein)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Spacer()
                            Text("Carbs: \(Int(carbsPct))%")
                                .foregroundColor(Color.macroCarbs)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Spacer()
                            Text("Fat: \(Int(fatPct))%")
                                .foregroundColor(Color.macroFats)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                    }
                    .softCardStyle()
                    .padding(.horizontal)
                    
                    // End of Dashboard Modules
                    
                    // Daily Goals section
                    if !goalFoods.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Daily Menu")
                                .font(.headline)
                                .padding(.horizontal)
                                
                            ForEach(goalFoods) { goalFood in
                                DailyGoalCardView(goalFood: goalFood, todayEntries: todayEntries)
                            }
                        }
                    }
                    
                    // Logging Forms
                    VStack(alignment: .leading) {
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
                            TextField("🔍 Search your foods...", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            if !foodDatabase.isEmpty {
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(searchResults) { food in
                                            Button(action: {
                                                selectedFood = food
                                                searchText = ""
                                            }) {
                                                HStack {
                                                    Text(food.name)
                                                        .font(.footnote)
                                                        .bold()
                                                        .foregroundColor(Color.pastelText)
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption2)
                                                        .foregroundColor(Color.pastelTextMuted)
                                                }
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 12)
                                                .background(Color.pastelCard)
                                                .cornerRadius(12)
                                                .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                }
                                .frame(height: 120)
                            }
                            
                            if let selected = selectedFood {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(selected.name)
                                                .font(.footnote)
                                                .bold()
                                                .foregroundColor(Color.pastelText)
                                            Spacer()
                                            Text("\(Int(selected.caloriesPer100g)) kcal/100g")
                                                .font(.caption2)
                                                .foregroundColor(Color.pastelTextMuted)
                                        }
                                        Text("\(selected.unitName) (\(Int(selected.unitWeightGrams))g)")
                                            .font(.caption2)
                                            .foregroundColor(Color.pastelTextMuted)
                                    }
                                    
                                    TextField("Amt", text: $amountToLogStr)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 40)
                                        .font(.caption2)
                                    
                                    Button("Log") {
                                        logSelectedFood()
                                    }
                                    .font(.caption2)
                                    .bold()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.pastelText)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .disabled(amountToLogStr.isEmpty)
                                    
                                    Button(action: { selectedFood = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color.macroProteinText)
                                            .font(.title3.bold())
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.pastelCard)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
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
                                        .font(.footnote)
                                        .bold()
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
                            .background(Color.macroProtein) // Reset Day is Red
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
    
    private func logSelectedFood() {
        guard let food = selectedFood else { return }
        let cleanAmount = Double(amountToLogStr.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        let totalGrams = cleanAmount * food.unitWeightGrams
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
        amountToLogStr = "1"
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
                }
                ForEach(histories) { history in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(history.dateSaved, style: .date)
                            .font(.headline)
                        
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
                        .font(.caption)
                        .foregroundColor(.gray)
                        
                        if history.containsAdHoc {
                            Text("⚠️ Appx metrics (contained out-of-menu items)")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("History")
        }
    }
}

// MARK: - Daily Goal Card View
struct DailyGoalCardView: View {
    let goalFood: FoodItem
    let todayEntries: [DailyEntry]
    @Environment(\.modelContext) private var modelContext
    
    @State private var logAmountStr = ""
    
    var consumedUnits: Double {
        todayEntries.filter { $0.foodItem == goalFood }.reduce(0.0) { $0 + ($1.consumedGrams / goalFood.unitWeightGrams) }
    }
    
    var remaining: Double {
        max(0, goalFood.dailyGoalAmount - consumedUnits)
    }
    
    var isDone: Bool { remaining == 0 }
    
    var body: some View {
            HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(goalFood.name)
                        .font(.footnote)
                        .bold()
                        .foregroundColor(Color.pastelText)
                    Spacer()
                    Text("\(consumedUnits, specifier: "%.1f") / \(goalFood.dailyGoalAmount, specifier: "%.1f")")
                        .font(.caption2)
                        .foregroundColor(Color.pastelTextMuted)
                }
                
                ProgressBarView(
                    progress: consumedUnits / max(0.001, goalFood.dailyGoalAmount),
                    color: isDone ? Color.macroCalories : Color(hex: "a2d2ff") // Distinct pastel blue
                )
                .frame(height: 5)
            }
            
            if !isDone {
                TextField("Amt", text: $logAmountStr)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 40)
                    .font(.caption2)
                
                Button("Log") {
                    let cleanAmount = Double(logAmountStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                    if cleanAmount > 0 {
                        logDirectly(amount: cleanAmount)
                        logAmountStr = ""
                    }
                }
                .font(.caption2)
                .bold()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.pastelText)
                .foregroundColor(.white)
                .cornerRadius(6)
                .disabled(logAmountStr.isEmpty)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.macroCalories)
                    .font(.title3)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.pastelCard)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func logDirectly(amount: Double) {
        let totalGrams = amount * goalFood.unitWeightGrams
        let multiplier = totalGrams / 100.0
        
        let entry = DailyEntry(
            timestamp: Date(),
            foodItem: goalFood,
            isAdHoc: false,
            consumedGrams: totalGrams,
            protein: goalFood.proteinPer100g * multiplier,
            carbs: goalFood.carbsPer100g * multiplier,
            fat: goalFood.fatPer100g * multiplier,
            fiber: goalFood.fiberPer100g * multiplier,
            calories: goalFood.caloriesPer100g * multiplier
        )
        
        withAnimation {
            modelContext.insert(entry)
            try? modelContext.save()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}

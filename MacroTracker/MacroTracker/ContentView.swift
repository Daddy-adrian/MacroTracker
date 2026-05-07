//
//  ContentView.swift
//  MacroTracker
//
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
            try modelContext.delete(model: BodyMetricsLog.self)
            try modelContext.save()
        } catch {}
    }
}

// MARK: - Setup / Profile View
struct SetupView: View {
    @Environment(\.modelContext) private var modelContext
    var existingProfile: UserProfile?
    
    @Query(sort: \BodyMetricsLog.date, order: .reverse) private var metricsLogs: [BodyMetricsLog]
    
    @State private var weightStr = "67.0"
    @State private var heightStr = "172.0"
    @State private var ageStr = "28"
    @State private var waistStr = "87.0"
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
    
    @State private var manualCaloriesStr = ""
    @State private var manualProteinStr = ""
    @State private var hasEditedTargets = false
    @State private var showingSavedAlert = false
    
    @State private var smartNotificationsEnabled = false
    @State private var usualWorkoutTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    
    var weight: Double { Double(weightStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var waist: Double? {
        let val = Double(waistStr.replacingOccurrences(of: ",", with: "."))
        return val != nil && val! > 0 ? val : nil
    }
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
        if hasEditedTargets, let val = Double(manualCaloriesStr.replacingOccurrences(of: ",", with: ".")) {
            return val
        }
        return max(defaultCalories, bmr)
    }
    
    var displayProtein: Double {
        if hasEditedTargets, let val = Double(manualProteinStr.replacingOccurrences(of: ",", with: ".")) {
            return val
        }
        return max(defaultProtein, minimumProtein)
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
        .onAppear { 
            loadExisting() 
            if existingProfile == nil {
                loadFromCloud()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            if existingProfile == nil {
                loadFromCloud()
            }
        }
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
                TextField("Waist (cm)", text: $waistStr).keyboardType(.decimalPad)
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
                
                Section(header: Text("Daily Targets"), footer: Text("Manual tweaks are saved until you reset them.")) {
                    HStack {
                        Text("Calories (kcal)")
                        Spacer()
                        TextField("\(Int(max(defaultCalories, bmr)))", text: $manualCaloriesStr)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .onChange(of: manualCaloriesStr) { hasEditedTargets = true }
                    }
                    
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("\(Int(max(defaultProtein, minimumProtein)))", text: $manualProteinStr)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .onChange(of: manualProteinStr) { hasEditedTargets = true }
                    }
                    
                    if hasEditedTargets {
                        Button("Reset to Recommended") {
                            manualCaloriesStr = ""
                            manualProteinStr = ""
                            hasEditedTargets = false
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
            
            if !metricsLogs.isEmpty {
                Section(header: Text("📈 Progress History")) {
                    ForEach(metricsLogs) { log in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(log.date, style: .date)
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color.pastelText)
                                Spacer()
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(Color.pastelTextMuted)
                            }
                            
                            HStack(spacing: 15) {
                                Label {
                                    Text("\(log.weightKg, specifier: "%.1f") kg")
                                        .font(.system(.body, design: .rounded))
                                } icon: {
                                    Image(systemName: "scalemass.fill")
                                        .foregroundColor(Color.macroProteinText)
                                }
                                
                                if let w = log.waistCm, w > 0 {
                                    Label {
                                        Text("\(w, specifier: "%.1f") cm")
                                            .font(.system(.body, design: .rounded))
                                    } icon: {
                                        Image(systemName: "ruler.fill")
                                            .foregroundColor(Color.macroCaloriesText)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.pastelCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
    }
    
    private func loadExisting() {
        if let profile = existingProfile {
            weightStr = String(format: "%.1f", profile.weightKg)
            if let w = profile.waistCm { waistStr = String(format: "%.1f", w) }
            heightStr = String(format: "%.1f", profile.heightCm)
            ageStr = "\(profile.age)"
            isMale = profile.isMale
            goal = profile.goal
            activityLevel = profile.activityLevel
            
            // Set inputs to saved state
            manualCaloriesStr = String(format: "%.0f", profile.targetCalories)
            manualProteinStr = String(format: "%.0f", profile.targetProtein)
            hasEditedTargets = true
            
            smartNotificationsEnabled = profile.smartNotificationsEnabled
            if let wTime = profile.usualWorkoutTime {
                usualWorkoutTime = wTime
            }
        }
    }
    
    private func loadFromCloud() {
        let store = NSUbiquitousKeyValueStore.default
        let cloudWeight = store.double(forKey: "bk_weight")
        let cloudHeight = store.double(forKey: "bk_height")
        let cloudAge = store.longLong(forKey: "bk_age")
        let cloudGoal = store.string(forKey: "bk_goal")
        let cloudActivity = store.double(forKey: "bk_activity")
        let cloudWaist = store.double(forKey: "bk_waist")
        let cloudIsMale = store.object(forKey: "bk_isMale") as? Bool
        
        if cloudWeight > 0 { weightStr = String(format: "%.1f", cloudWeight) }
        if cloudHeight > 0 { heightStr = String(format: "%.1f", cloudHeight) }
        if cloudAge > 0 { ageStr = "\(cloudAge)" }
        if let cg = cloudGoal { goal = cg }
        if cloudActivity > 0 { activityLevel = cloudActivity }
        if cloudWaist > 0 { waistStr = String(format: "%.1f", cloudWaist) }
        if let cim = cloudIsMale { isMale = cim }
        
        let cloudCals = store.double(forKey: "bk_targetCalories")
        let cloudProt = store.double(forKey: "bk_targetProtein")
        if cloudCals > 0 && cloudProt > 0 {
            manualCaloriesStr = String(format: "%.0f", cloudCals)
            manualProteinStr = String(format: "%.0f", cloudProt)
            hasEditedTargets = true
        }
    }
    
    private func saveProfile() {
        let finalWaist = waist
        if let profile = existingProfile {
            profile.weightKg = weight
            profile.waistCm = finalWaist
            profile.heightCm = height
            profile.age = age
            profile.isMale = isMale
            profile.goal = goal
            profile.activityLevel = activityLevel
            profile.targetCalories = displayCalories
            profile.targetProtein = displayProtein
            profile.smartNotificationsEnabled = smartNotificationsEnabled
            profile.usualWorkoutTime = usualWorkoutTime
            profile.syncToCloud()
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
                usualWorkoutTime: usualWorkoutTime,
                waistCm: finalWaist
            )
            modelContext.insert(profile)
            profile.syncToCloud()
        }
        
        let log = BodyMetricsLog(date: Date(), weightKg: weight, waistCm: finalWaist)
        modelContext.insert(log)
        
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
        let cleanInputStr = inputStr.replacingOccurrences(of: ",", with: "." registry: .localized)
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
        let filtered = foodDatabase.filter { food in
            if let goal = food.dailyGoal, goal > 0 {
                let units = unitsConsumed(for: food)
                return units < Double(goal)
            }
            return false
        }
        return filtered.sorted { 
            if $0.name == "Omega 3 & Creatine" { return false }
            if $1.name == "Omega 3 & Creatine" { return true }
            return $0.name < $1.name
        }
    }
    
    func unitsConsumed(for food: FoodItem) -> Double {
        let grams = todayEntries.filter { $0.foodItem?.id == food.id }.reduce(0) { $0 + $1.consumedGrams }
        return grams / max(1.0, food.unitWeight)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Modern Header Card
                    VStack(spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Today's Balance")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("\(Int(max(0, profile.targetCalories - consumedCalories))) kcal left")
                                    .font(.system(.title, design: .rounded)).bold()
                                    .foregroundColor(Color.pastelText)
                            }
                            Spacer()
                            CircularProgressView(progress: consumedCalories / profile.targetCalories, color: Color.macroCalories, lineWidth: 12)
                                .frame(width: 70, height: 70)
                        }
                        
                        Divider()
                        
                        HStack(spacing: 20) {
                            MacroStatusView(label: "Protein", consumed: consumedProtein, target: profile.targetProtein, color: Color.macroProtein)
                            MacroStatusView(label: "Carbs", consumed: consumedCarbs, target: profile.targetCalories * 0.4 / 4, color: Color.macroCarbs)
                            MacroStatusView(label: "Fats", consumed: consumedFat, target: profile.targetCalories * 0.3 / 9, color: Color.macroFats)
                        }
                    }
                    .softCardStyle()
                    .padding(.horizontal)
                    
                    // Quick Goal Tracker
                    if !activeGoalFoods.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Daily Goals")
                                .font(.headline)
                                .foregroundColor(Color.pastelText)
                                .padding(.leading)
                            
                            ForEach(activeGoalFoods) { food in
                                GoalTrackerRow(food: food, consumed: unitsConsumed(for: food))
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Main Log Button
                    Button(action: { showingAdHocMenu = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log Something Else")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.macroCalories)
                        .cornerRadius(24)
                    }
                    .padding(.horizontal)
                    
                    // Recent Timeline
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .foregroundColor(Color.pastelText)
                        
                        if todayEntries.isEmpty {
                            Text("No entries yet today.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(todayEntries) { entry in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(entry.isAdHoc ? entry.adHocName : (entry.foodItem?.name ?? "Unknown"))
                                            .font(.subheadline.bold())
                                        Text("\(Int(entry.consumedGrams))g • \(Int(entry.calories)) kcal")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            modelContext.delete(entry)
                                            try? modelContext.save()
                                        }
                                    }) {
                                        Image(systemName: "trash").foregroundColor(.red.opacity(0.6))
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("MacroTracker")
            .sheet(isPresented: $showingAdHocMenu) {
                QuickAddView()
            }
        }
    }
}

struct MacroStatusView: View {
    let label: String
    let consumed: Double
    let target: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label).font(.caption).foregroundColor(.gray)
            ProgressBarView(progress: consumed / max(1.0, target), color: color)
            Text("\(Int(consumed))g").font(.caption.bold())
        }
    }
}

struct QuickAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foodDatabase: [FoodItem]
    
    @State private var selectedFood: FoodItem?
    @State private var gramsToLogStr = "100"
    
    @State private var isAdHoc = false
    @State private var adHocName = ""
    @State private var adHocProteinStr = ""
    @State private var adHocCaloriesStr = ""
    
    var body: some View {
        NavigationView {
            Form {
                Picker("Log Type", selection: $isAdHoc) {
                    Text("From Menu").tag(false)
                    Text("Quick/Manual").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .listRowBackground(Color.white)
                
                if isAdHoc {
                    Section(header: Text("Manual Entry")) {
                        TextField("Name", text: $adHocName)
                        TextField("Protein (g)", text: $adHocProteinStr).keyboardType(.decimalPad)
                        TextField("Calories (kcal)", text: $adHocCaloriesStr).keyboardType(.decimalPad)
                    }
                    .listRowBackground(Color.white)
                } else {
                    Section(header: Text("Select from Menu")) {
                        Picker("Food Item", selection: $selectedFood) {
                            Text("Choose...").tag(nil as FoodItem?)
                            ForEach(foodDatabase) { food in
                                Text(food.name).tag(food as FoodItem?)
                            }
                        }
                        TextField("Amount (grams)", text: $gramsToLogStr).keyboardType(.decimalPad)
                    }
                    .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("Log Food")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() }.bold().foregroundColor(Color.macroProteinText),
                trailing: Button("Add") { logFood() }.bold().disabled(!isFormValid).foregroundColor(isFormValid ? Color.macroCaloriesText : .gray)
            )
        }
    }
    
    var isFormValid: Bool {
        if isAdHoc {
            return !adHocName.isEmpty && !adHocProteinStr.isEmpty && !adHocCaloriesStr.isEmpty
        } else {
            return selectedFood != nil && !gramsToLogStr.isEmpty
        }
    }
    
    private func logFood() {
        if isAdHoc {
            let p = Double(adHocProteinStr.replacingOccurrences(of: ",", with: ".")) ?? 0
            let c = Double(adHocCaloriesStr.replacingOccurrences(of: ",", with: ".")) ?? 0
            let entry = DailyEntry(timestamp: Date(), isAdHoc: true, adHocName: adHocName, consumedGrams: 0, protein: p, carbs: 0, fat: 0, fiber: 0, calories: c)
            modelContext.insert(entry)
        } else if let food = selectedFood {
            let grams = Double(gramsToLogStr.replacingOccurrences(of: ",", with: ".")) ?? 100
            let multiplier = grams / 100.0
            let entry = DailyEntry(
                timestamp: Date(),
                foodItem: food,
                isAdHoc: false,
                consumedGrams: grams,
                protein: food.proteinPer100g * multiplier,
                carbs: food.carbsPer100g * multiplier,
                fat: food.fatPer100g * multiplier,
                fiber: food.fiberPer100g * multiplier,
                calories: food.caloriesPer100g * multiplier
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - History View
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyHistory.dateSaved, order: .reverse) private var history: [DailyHistory]
    
    var body: some View {
        NavigationView {
            List {
                if history.isEmpty {
                    Text("No history saved yet. Complete a day to see it here!")
                        .foregroundColor(.gray)
                        .listRowBackground(Color.pastelCard)
                }
                ForEach(history) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(day.dateSaved, style: .date)
                                .font(.headline)
                                .foregroundColor(Color.pastelText)
                            Spacer()
                            Text("\(Int(day.totalCalories)) kcal")
                                .font(.subheadline.bold())
                                .foregroundColor(Color.macroCaloriesText)
                        }
                        
                        HStack {
                            MacroTag(label: "P", value: day.totalProtein, color: Color.macroProtein)
                            MacroTag(label: "C", value: day.totalCarbs, color: Color.macroCarbs)
                            MacroTag(label: "F", value: day.totalFat, color: Color.macroFats)
                            if day.totalFiber > 0 {
                                MacroTag(label: "Fib", value: day.totalFiber, color: Color.macroFiber)
                            }
                            if day.containsAdHoc {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.white)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(history[index])
                    }
                    try? modelContext.save()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("History")
        }
    }
}

struct MacroTag: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).bold()
            Text("\(Int(value))g").font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

// MARK: - Calculator View
struct CalorieCalculatorView: View {
    var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutEntry.timestamp, order: .reverse) private var workouts: [WorkoutEntry]
    
    @State private var showingAddWorkout = false
    
    var todayWorkouts: [WorkoutEntry] {
        workouts.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    var burnedCalories: Double {
        todayWorkouts.reduce(0) { $0 + $1.caloriesBurned }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Exercise Budget")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("+\(Int(burnedCalories)) kcal")
                                    .font(.title.bold())
                                    .foregroundColor(Color.macroCaloriesText)
                            }
                            Spacer()
                            Image(systemName: "figure.run.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color.macroCalories.opacity(0.8))
                        }
                        
                        Text("These calories are added to your daily goal.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .softCardStyle()
                    .padding(.horizontal)
                    
                    // Common Workouts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Add")
                            .font(.headline)
                            .foregroundColor(Color.pastelText)
                        
                        HStack(spacing: 12) {
                            WorkoutQuickButton(name: "Main Workout", calories: 250, icon: "figure.strengthtraining.functional", isAdded: hasWorkout("Main Workout")) {
                                toggleWorkout("Main Workout", cals: 250)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // History Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Sessions")
                            .font(.headline)
                            .foregroundColor(Color.pastelText)
                        
                        if todayWorkouts.isEmpty {
                            Text("No workouts logged yet.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            ForEach(todayWorkouts) { workout in
                                HStack {
                                    Text(workout.name)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("\(Int(workout.caloriesBurned)) kcal")
                                        .font(.subheadline)
                                        .foregroundColor(Color.macroCaloriesText)
                                    
                                    Button(action: { deleteWorkout(workout) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red.opacity(0.3))
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("Burner")
        }
    }
    
    private func hasWorkout(_ name: String) -> Bool {
        todayWorkouts.contains { $0.name == name }
    }
    
    private func toggleWorkout(_ name: String, cals: Double) {
        if let existing = todayWorkouts.first(where: { $0.name == name }) {
            modelContext.delete(existing)
        } else {
            let workout = WorkoutEntry(timestamp: Date(), name: name, caloriesBurned: cals)
            modelContext.insert(workout)
        }
        try? modelContext.save()
    }
    
    private func deleteWorkout(_ workout: WorkoutEntry) {
        modelContext.delete(workout)
        try? modelContext.save()
    }
}

struct WorkoutQuickButton: View {
    let name: String
    let calories: Int
    let icon: String
    let isAdded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(isAdded ? .white : Color.macroCalories)
                Text(name)
                    .font(.caption.bold())
                    .foregroundColor(isAdded ? .white : Color.pastelText)
                Text("\(calories) kcal")
                    .font(.caption2)
                    .foregroundColor(isAdded ? .white.opacity(0.8) : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isAdded ? Color.macroCalories : Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Modular Import UI
struct ImportMenuButton: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingImportSheet = false
    
    var body: some View {
        Button(action: { showingImportSheet = true }) {
            Image(systemName: "square.and.arrow.down")
                .foregroundColor(Color.macroCalories)
        }
        .sheet(isPresented: $showingImportSheet) {
            FoodImportView()
        }
    }
}

struct FoodImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputJSON: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Paste food data here to import into your menu.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextEditor(text: $inputJSON)
                    .frame(maxHeight: 300)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                    .padding()
                
                Button(action: processImport) {
                    Text("Start Import")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.macroCalories)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background(Color.pastelBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle("Import Menu")
            .navigationBarItems(trailing: Button("Close") { dismiss() })
            .alert("Import Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func processImport() {
        // Logic to parse JSON and insert into modelContext
        // For now, it's a placeholder for future scalability
        dismiss()
    }
}

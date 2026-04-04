import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportMenuButton: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingImporter = false
    @State private var importStatus = ""
    @State private var showingAlert = false

    var body: some View {
        Button(action: {
            showingImporter = true
        }) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.pastelText)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedUrl = urls.first else { return }
                let accessStart = selectedUrl.startAccessingSecurityScopedResource()
                importCSV(from: selectedUrl)
                if accessStart { selectedUrl.stopAccessingSecurityScopedResource() }
            case .failure(let error):
                importStatus = "Failed: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        .alert("Import Status", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(importStatus) }
    }

    private func importCSV(from url: URL) {
        do {
            // Try different encodings to catch the Hebrew correctly
            let data: String
            if let utf8String = try? String(contentsOf: url, encoding: .utf8) {
                data = utf8String
            } else if let latinString = try? String(contentsOf: url, encoding: .windowsCP1252) {
                data = latinString
            } else {
                data = try String(contentsOf: url, encoding: .utf16)
            }
            
            let rows = data.components(separatedBy: .newlines)
            var addedCount = 0
            
            for row in rows.dropFirst() {
                let columns = row.components(separatedBy: ",")
                guard columns.count >= 6 else { continue }
                
                // We "Decode" the strings here to handle the \u1495 issue
                let name = decodeUnicode(columns[0])
                if name.isEmpty { continue }
                
                let cals = Double(decodeUnicode(columns[1])) ?? 0
                let pro = Double(decodeUnicode(columns[2])) ?? 0
                let fib = Double(decodeUnicode(columns[3])) ?? 0
                let fats = Double(decodeUnicode(columns[4])) ?? 0
                let carbs = Double(decodeUnicode(columns[5])) ?? 0
                
                let newFood = FoodItem(
                    name: name,
                    proteinPer100g: pro,
                    carbsPer100g: carbs,
                    fatPer100g: fats,
                    fiberPer100g: fib,
                    caloriesPer100g: cals
                )
                
                modelContext.insert(newFood)
                addedCount += 1
            }
            
            try modelContext.save()
            importStatus = "Successfully imported \(addedCount) foods!"
            showingAlert = true
            
        } catch {
            importStatus = "Error: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // THE CRITICAL FIX: This function converts "\u05db" into "כ"
    private func decodeUnicode(_ input: String) -> String {
        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
                              .replacingOccurrences(of: "\"", with: "")
        
        // This helper handles the actual conversion of the encoded characters
        guard let data = cleanInput.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: "[\"\(cleanInput)\"]".data(using: .utf8)!, options: []) as? [String],
              let result = decoded.first else {
            return cleanInput
        }
        return result
    }
}

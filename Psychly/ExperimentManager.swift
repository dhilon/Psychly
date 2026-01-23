//
//  ExperimentManager.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import Foundation
import FirebaseFirestore

@MainActor
class ExperimentManager: ObservableObject {
    @Published var experiment: Experiment? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        return todayComponents.year == dateComponents.year &&
               todayComponents.month == dateComponents.month &&
               todayComponents.day == dateComponents.day
    }

    func loadExperiment(for date: Date) async {
        isLoading = true
        errorMessage = nil

        let dateStr = dateString(from: date)
        print("🔵 Loading experiment for date: \(dateStr)")
        print("🔵 Is today: \(isToday(date))")

        do {
            // Check if experiment exists for this date
            let document = try await db.collection("experiments").document(dateStr).getDocument()
            print("🔵 Document exists: \(document.exists)")

            if let data = document.data() {
                print("🟢 Found existing experiment: \(data)")
                experiment = Experiment(
                    name: data["name"] as? String ?? "",
                    info: data["info"] as? String ?? "",
                    date: data["date"] as? String ?? "",
                    researchers: data["researchers"] as? String ?? "",
                    question: data["question"] as? String ?? ""
                )
            } else if isToday(date) {
                print("🔵 No experiment for today, fetching from Gemini...")
                // No experiment for today, fetch from Gemini
                await fetchNewExperiment(for: date)
            } else {
                print("🟡 Past date with no experiment")
                // Past date with no experiment
                experiment = nil
            }
        } catch {
            print("🔴 Error loading experiment: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchNewExperiment(for date: Date) async {
        do {
            // Get list of existing experiment names to exclude
            let existingNames = try await getExistingExperimentNames()
            print("🔵 Existing experiment names to exclude: \(existingNames)")

            // Fetch new experiment from Gemini
            print("🔵 Calling Gemini API...")
            let newExperiment = try await GeminiService.shared.getRandomExperiment(excludingNames: existingNames)
            print("🟢 Got experiment from Gemini: \(newExperiment.name)")

            // Save to Firestore
            let dateStr = dateString(from: date)
            print("🔵 Saving to Firestore with date: \(dateStr)")

            let experimentData: [String: Any] = [
                "name": newExperiment.name,
                "info": newExperiment.info,
                "date": newExperiment.date,
                "researchers": newExperiment.researchers,
                "question": newExperiment.question
            ]
            print("🔵 Data to save: \(experimentData)")

            try await db.collection("experiments").document(dateStr).setData(experimentData)
            print("🟢 Successfully saved to Firestore")

            experiment = newExperiment
            print("🟢 Experiment set in manager")
        } catch {
            print("🔴 Error in fetchNewExperiment: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    private func getExistingExperimentNames() async throws -> [String] {
        let snapshot = try await db.collection("experiments").getDocuments()
        return snapshot.documents.compactMap { $0.data()["name"] as? String }
    }
}

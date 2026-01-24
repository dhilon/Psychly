//
//  CalendarManager.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import Foundation
import FirebaseFirestore

@MainActor
class CalendarManager: ObservableObject {
    @Published var experimentDates: Set<String> = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func loadExperimentDates() async {
        isLoading = true

        do {
            let snapshot = try await db.collection("experiments").getDocuments()
            experimentDates = Set(snapshot.documents.map { $0.documentID })
            print("🔵 Loaded experiment dates: \(experimentDates)")
        } catch {
            print("🔴 Error loading experiment dates: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func hasExperiment(for date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateStr = formatter.string(from: date)
        return experimentDates.contains(dateStr)
    }
}

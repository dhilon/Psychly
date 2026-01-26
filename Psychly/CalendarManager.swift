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
    @Published var experimentBadges: [String: String] = [:]
    @Published var isLoading = false

    private let db = Firestore.firestore()

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    func loadExperimentDates() async {
        isLoading = true

        do {
            let snapshot = try await db.collection("experiments").getDocuments()
            experimentDates = Set(snapshot.documents.map { $0.documentID })

            // Load badge icons
            for document in snapshot.documents {
                let dateStr = document.documentID
                if let badgeIcon = document.data()["badgeIcon"] as? String {
                    experimentBadges[dateStr] = badgeIcon
                }
            }
            print("🔵 Loaded experiment dates: \(experimentDates)")
            print("🔵 Loaded \(experimentBadges.count) badge icons")
        } catch {
            print("🔴 Error loading experiment dates: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func hasExperiment(for date: Date) -> Bool {
        let dateStr = dateString(from: date)
        return experimentDates.contains(dateStr)
    }

    func getBadgeIcon(for date: Date) -> String? {
        let dateStr = dateString(from: date)
        return experimentBadges[dateStr]
    }

    func getUsedBadgeIcons() -> Set<String> {
        return Set(experimentBadges.values)
    }
}

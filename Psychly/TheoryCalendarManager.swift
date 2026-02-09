//
//  TheoryCalendarManager.swift
//  Psychly
//
//  Created by Dhilon Prasad on 2/6/26.
//

import Foundation
import FirebaseFirestore

@MainActor
class TheoryCalendarManager: ObservableObject {
    @Published var theoryDates: Set<String> = []
    @Published var theoryBadges: [String: String] = [:]
    @Published var isLoading = false

    private let db = Firestore.firestore()

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    func loadTheoryDates() async {
        isLoading = true

        do {
            let snapshot = try await db.collection("theories").getDocuments()
            theoryDates = Set(snapshot.documents.map { $0.documentID })

            // Load badge icons
            for document in snapshot.documents {
                let dateStr = document.documentID
                if let badgeIcon = document.data()["badgeIcon"] as? String {
                    theoryBadges[dateStr] = badgeIcon
                }
            }
            print("🔵 Loaded theory dates: \(theoryDates)")
            print("🔵 Loaded \(theoryBadges.count) theory badge icons")
        } catch {
            print("🔴 Error loading theory dates: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func hasTheory(for date: Date) -> Bool {
        let dateStr = dateString(from: date)
        return theoryDates.contains(dateStr)
    }

    func getBadgeIcon(for date: Date) -> String? {
        let dateStr = dateString(from: date)
        return theoryBadges[dateStr]
    }

    func getUsedBadgeIcons() -> Set<String> {
        return Set(theoryBadges.values)
    }
}

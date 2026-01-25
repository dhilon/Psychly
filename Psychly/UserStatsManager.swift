//
//  UserStatsManager.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class UserStatsManager: ObservableObject {
    @Published var daysAchieved: Int = 0
    @Published var streak: Int = 0
    @Published var worldRank: Int = 0
    @Published var viewedDates: Set<String> = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    func loadStats() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isLoading = true

        do {
            let document = try await db.collection("userStats").document(userId).getDocument()

            if let data = document.data(),
               let dates = data["viewedDates"] as? [String] {
                viewedDates = Set(dates)
                daysAchieved = viewedDates.count
                streak = calculateStreak()
                print("🔵 Loaded user stats: \(daysAchieved) days, \(streak) streak")
            } else {
                viewedDates = []
                daysAchieved = 0
                streak = 0
            }

            // Calculate world rank
            await calculateWorldRank()
        } catch {
            print("🔴 Error loading user stats: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func calculateWorldRank() async {
        do {
            // Get all users' stats
            let snapshot = try await db.collection("userStats").getDocuments()

            // Get all users' days achieved counts
            var allDaysAchieved: [Int] = []
            for document in snapshot.documents {
                if let dates = document.data()["viewedDates"] as? [String] {
                    allDaysAchieved.append(dates.count)
                }
            }

            // Sort in descending order
            allDaysAchieved.sort(by: >)

            // Find current user's rank (1-indexed)
            if let rank = allDaysAchieved.firstIndex(where: { $0 <= daysAchieved }) {
                worldRank = rank + 1
            } else {
                worldRank = allDaysAchieved.count + 1
            }

            print("🔵 World rank: \(worldRank) out of \(allDaysAchieved.count) users")
        } catch {
            print("🔴 Error calculating world rank: \(error.localizedDescription)")
            worldRank = 0
        }
    }

    func recordView(for date: Date) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let dateStr = dateString(from: date)

        // Load stats first if not already loaded
        if viewedDates.isEmpty {
            await loadStats()
        }

        // Don't record if already viewed
        if viewedDates.contains(dateStr) {
            print("🔵 Already viewed \(dateStr), skipping")
            return
        }

        // Update local state
        viewedDates.insert(dateStr)
        daysAchieved = viewedDates.count
        streak = calculateStreak()

        do {
            // Use arrayUnion to add to the array without overwriting existing dates
            try await db.collection("userStats").document(userId).setData([
                "viewedDates": FieldValue.arrayUnion([dateStr])
            ], merge: true)
            print("🟢 Recorded view for \(dateStr). Total days: \(daysAchieved), Streak: \(streak)")

            // Recalculate world rank after recording
            await calculateWorldRank()
        } catch {
            print("🔴 Error recording view: \(error.localizedDescription)")
        }
    }

    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        var currentStreak = 0
        var checkDate = Date() // Start from today

        while true {
            let dateStr = dateString(from: checkDate)
            if viewedDates.contains(dateStr) {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return currentStreak
    }
}

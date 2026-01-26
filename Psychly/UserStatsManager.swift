//
//  UserStatsManager.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct UserAnswer: Codable {
    let correct: Bool
    let guess: String
    let timestamp: Date

    var asDictionary: [String: Any] {
        return [
            "correct": correct,
            "guess": guess,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
}

@MainActor
class UserStatsManager: ObservableObject {
    @Published var daysAchieved: Int = 0
    @Published var streak: Int = 0
    @Published var worldRank: Int = 0
    @Published var viewedDates: Set<String> = []
    @Published var answers: [String: UserAnswer] = [:]
    @Published var isLoading = false

    private let db = Firestore.firestore()

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    func hasAnswered(for date: Date) -> Bool {
        let dateStr = dateString(from: date)
        return answers[dateStr] != nil
    }

    func getAnswer(for date: Date) -> UserAnswer? {
        let dateStr = dateString(from: date)
        return answers[dateStr]
    }

    func loadStats() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isLoading = true

        do {
            let document = try await db.collection("userStats").document(userId).getDocument()

            if let data = document.data() {
                if let dates = data["viewedDates"] as? [String] {
                    viewedDates = Set(dates)
                    daysAchieved = viewedDates.count
                    streak = calculateStreak()
                    print("🔵 Loaded user stats: \(daysAchieved) days, \(streak) streak")
                }

                // Load answers - check for nested structure first
                if let answersData = data["answers"] as? [String: Any] {
                    print("🔵 Found nested answers data: \(answersData)")
                    for (dateStr, value) in answersData {
                        print("🔵 Processing answer for \(dateStr): \(value)")
                        // Handle full answer object
                        if let answerDict = value as? [String: Any],
                           let correct = answerDict["correct"] as? Bool {
                            let guess = answerDict["guess"] as? String ?? ""
                            let timestamp = (answerDict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                            answers[dateStr] = UserAnswer(
                                correct: correct,
                                guess: guess,
                                timestamp: timestamp
                            )
                            print("🟢 Loaded answer for \(dateStr): correct=\(correct)")
                        }
                        // Handle simple boolean format (for manually seeded data)
                        else if let correct = value as? Bool {
                            answers[dateStr] = UserAnswer(
                                correct: correct,
                                guess: "",
                                timestamp: Date()
                            )
                            print("🟢 Loaded simple answer for \(dateStr): correct=\(correct)")
                        }
                    }
                    print("🔵 Loaded \(answers.count) answers total")
                } else {
                    // Check for flat "answers.YYYY-MM-DD" keys (manually seeded data)
                    print("🔵 Checking for flat answer keys in: \(data.keys)")
                    for key in data.keys {
                        if key.hasPrefix("answers.") {
                            let dateStr = String(key.dropFirst("answers.".count))
                            if let answerDict = data[key] as? [String: Any],
                               let correct = answerDict["correct"] as? Bool {
                                let guess = answerDict["guess"] as? String ?? ""
                                let timestamp = (answerDict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                                answers[dateStr] = UserAnswer(
                                    correct: correct,
                                    guess: guess,
                                    timestamp: timestamp
                                )
                                print("🟢 Loaded flat answer for \(dateStr): correct=\(correct)")
                            } else if let correct = data[key] as? Bool {
                                answers[dateStr] = UserAnswer(
                                    correct: correct,
                                    guess: "",
                                    timestamp: Date()
                                )
                                print("🟢 Loaded flat boolean answer for \(dateStr): correct=\(correct)")
                            }
                        }
                    }
                    if answers.isEmpty {
                        print("🟡 No answers found in any format")
                    } else {
                        print("🔵 Loaded \(answers.count) answers from flat keys")
                    }
                }
            } else {
                viewedDates = []
                daysAchieved = 0
                streak = 0
                answers = [:]
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

    func recordAnswer(for date: Date, correct: Bool, guess: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let dateStr = dateString(from: date)

        // Don't record if already answered
        if answers[dateStr] != nil {
            print("🔵 Already answered for \(dateStr), skipping")
            return
        }

        let answer = UserAnswer(correct: correct, guess: guess, timestamp: Date())

        // Update local state
        answers[dateStr] = answer
        viewedDates.insert(dateStr)
        daysAchieved = viewedDates.count
        streak = calculateStreak()

        do {
            // Save to Firestore
            try await db.collection("userStats").document(userId).setData([
                "viewedDates": FieldValue.arrayUnion([dateStr]),
                "answers.\(dateStr)": answer.asDictionary
            ], merge: true)
            print("🟢 Recorded answer for \(dateStr). Correct: \(correct)")

            // Recalculate world rank after recording
            await calculateWorldRank()
        } catch {
            print("🔴 Error recording answer: \(error.localizedDescription)")
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

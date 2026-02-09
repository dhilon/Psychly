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
    @Published var answers: [String: UserAnswer] = [:]  // Legacy - kept for compatibility
    @Published var experimentAnswers: [String: UserAnswer] = [:]
    @Published var theoryAnswers: [String: UserAnswer] = [:]
    @Published var isLoading = false

    /// Returns array of date strings where the user answered correctly (experiment or theory)
    var correctAnswerDates: [String] {
        let experimentCorrect = experimentAnswers.filter { $0.value.correct }.map { $0.key }
        let theoryCorrect = theoryAnswers.filter { $0.value.correct }.map { $0.key }
        return Set(experimentCorrect + theoryCorrect).sorted { $0 > $1 }
    }

    private let db = Firestore.firestore()

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    // MARK: - Legacy Methods (for backwards compatibility)

    func hasAnswered(for date: Date) -> Bool {
        return hasAnsweredExperiment(for: date)
    }

    func getAnswer(for date: Date) -> UserAnswer? {
        return getExperimentAnswer(for: date)
    }

    // MARK: - Experiment Answer Methods

    func hasAnsweredExperiment(for date: Date) -> Bool {
        let dateStr = dateString(from: date)
        return experimentAnswers[dateStr] != nil
    }

    func getExperimentAnswer(for date: Date) -> UserAnswer? {
        let dateStr = dateString(from: date)
        return experimentAnswers[dateStr]
    }

    // MARK: - Theory Answer Methods

    func hasAnsweredTheory(for date: Date) -> Bool {
        let dateStr = dateString(from: date)
        return theoryAnswers[dateStr] != nil
    }

    func getTheoryAnswer(for date: Date) -> UserAnswer? {
        let dateStr = dateString(from: date)
        return theoryAnswers[dateStr]
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
                    print("🔵 Loaded user stats: \(daysAchieved) days")
                }

                // Load experiment answers
                if let expAnswersData = data["experimentAnswers"] as? [String: Any] {
                    print("🔵 Found experimentAnswers data: \(expAnswersData)")
                    loadAnswersFromData(expAnswersData, into: &experimentAnswers, label: "experiment")
                }

                // Load theory answers
                if let theoryAnswersData = data["theoryAnswers"] as? [String: Any] {
                    print("🔵 Found theoryAnswers data: \(theoryAnswersData)")
                    loadAnswersFromData(theoryAnswersData, into: &theoryAnswers, label: "theory")
                }

                // Migration: Load legacy "answers" into experimentAnswers if experimentAnswers is empty
                if experimentAnswers.isEmpty {
                    if let answersData = data["answers"] as? [String: Any] {
                        print("🔵 Migrating legacy answers to experimentAnswers")
                        loadAnswersFromData(answersData, into: &experimentAnswers, label: "legacy->experiment")
                        // Also keep in legacy answers for backwards compatibility
                        answers = experimentAnswers
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
                                    let answer = UserAnswer(correct: correct, guess: guess, timestamp: timestamp)
                                    experimentAnswers[dateStr] = answer
                                    answers[dateStr] = answer
                                    print("🟢 Loaded flat answer for \(dateStr): correct=\(correct)")
                                } else if let correct = data[key] as? Bool {
                                    let answer = UserAnswer(correct: correct, guess: "", timestamp: Date())
                                    experimentAnswers[dateStr] = answer
                                    answers[dateStr] = answer
                                    print("🟢 Loaded flat boolean answer for \(dateStr): correct=\(correct)")
                                }
                            }
                        }
                    }
                }

                // Calculate streak with new combined logic
                streak = calculateStreak()
                print("🔵 Calculated streak: \(streak)")
            } else {
                viewedDates = []
                daysAchieved = 0
                streak = 0
                answers = [:]
                experimentAnswers = [:]
                theoryAnswers = [:]
            }

            // Calculate world rank
            await calculateWorldRank()
        } catch {
            print("🔴 Error loading user stats: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func loadAnswersFromData(_ data: [String: Any], into answers: inout [String: UserAnswer], label: String) {
        for (dateStr, value) in data {
            if let answerDict = value as? [String: Any],
               let correct = answerDict["correct"] as? Bool {
                let guess = answerDict["guess"] as? String ?? ""
                let timestamp = (answerDict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                answers[dateStr] = UserAnswer(correct: correct, guess: guess, timestamp: timestamp)
                print("🟢 Loaded \(label) answer for \(dateStr): correct=\(correct)")
            } else if let correct = value as? Bool {
                answers[dateStr] = UserAnswer(correct: correct, guess: "", timestamp: Date())
                print("🟢 Loaded simple \(label) answer for \(dateStr): correct=\(correct)")
            }
        }
        print("🔵 Loaded \(answers.count) \(label) answers total")
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

    // MARK: - Legacy recordAnswer (maps to experiment)
    func recordAnswer(for date: Date, correct: Bool, guess: String) async {
        await recordExperimentAnswer(for: date, correct: correct, guess: guess)
    }

    // MARK: - Record Experiment Answer
    func recordExperimentAnswer(for date: Date, correct: Bool, guess: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let dateStr = dateString(from: date)

        // Don't record if already answered
        if experimentAnswers[dateStr] != nil {
            print("🔵 Already answered experiment for \(dateStr), skipping")
            return
        }

        let answer = UserAnswer(correct: correct, guess: guess, timestamp: Date())

        // Update local state
        experimentAnswers[dateStr] = answer
        answers[dateStr] = answer  // Keep legacy in sync
        viewedDates.insert(dateStr)
        daysAchieved = viewedDates.count
        streak = calculateStreak()

        do {
            // Save to Firestore
            try await db.collection("userStats").document(userId).setData([
                "viewedDates": FieldValue.arrayUnion([dateStr]),
                "experimentAnswers.\(dateStr)": answer.asDictionary
            ], merge: true)
            print("🟢 Recorded experiment answer for \(dateStr). Correct: \(correct)")

            // Recalculate world rank after recording
            await calculateWorldRank()
        } catch {
            print("🔴 Error recording experiment answer: \(error.localizedDescription)")
        }
    }

    // MARK: - Record Theory Answer
    func recordTheoryAnswer(for date: Date, correct: Bool, guess: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let dateStr = dateString(from: date)

        // Don't record if already answered
        if theoryAnswers[dateStr] != nil {
            print("🔵 Already answered theory for \(dateStr), skipping")
            return
        }

        let answer = UserAnswer(correct: correct, guess: guess, timestamp: Date())

        // Update local state
        theoryAnswers[dateStr] = answer
        viewedDates.insert(dateStr)
        daysAchieved = viewedDates.count
        streak = calculateStreak()

        do {
            // Save to Firestore
            try await db.collection("userStats").document(userId).setData([
                "viewedDates": FieldValue.arrayUnion([dateStr]),
                "theoryAnswers.\(dateStr)": answer.asDictionary
            ], merge: true)
            print("🟢 Recorded theory answer for \(dateStr). Correct: \(correct)")

            // Recalculate world rank after recording
            await calculateWorldRank()
        } catch {
            print("🔴 Error recording theory answer: \(error.localizedDescription)")
        }
    }

    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        var currentStreak = 0
        var checkDate = Date() // Start from today

        while true {
            let dateStr = dateString(from: checkDate)

            // Streak continues if user answered EITHER game correctly
            let experimentCorrect = experimentAnswers[dateStr]?.correct == true
            let theoryCorrect = theoryAnswers[dateStr]?.correct == true

            if experimentCorrect || theoryCorrect {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return currentStreak
    }
}

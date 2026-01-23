//
//  VoteManager.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class VoteManager: ObservableObject {
    @Published var likeCount: Int = 0
    @Published var dislikeCount: Int = 0
    @Published var userVote: String? = nil
    @Published var isLoading = false

    private let db = Firestore.firestore()

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    func loadVotes(for date: Date) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isLoading = true
        let dateStr = dateString(from: date)

        do {
            let document = try await db.collection("dailyVotes").document(dateStr).getDocument()

            if let data = document.data() {
                likeCount = data["likeCount"] as? Int ?? 0
                dislikeCount = data["dislikeCount"] as? Int ?? 0

                if let votes = data["userVotes"] as? [String: String] {
                    userVote = votes[userId]
                } else {
                    userVote = nil
                }
            } else {
                likeCount = 0
                dislikeCount = 0
                userVote = nil
            }
        } catch {
            print("Error loading votes: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func vote(for date: Date, voteType: String?) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let dateStr = dateString(from: date)
        let docRef = db.collection("dailyVotes").document(dateStr)

        do {
            try await db.runTransaction { transaction, errorPointer in
                let document: DocumentSnapshot
                do {
                    document = try transaction.getDocument(docRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                var likeCount = document.data()?["likeCount"] as? Int ?? 0
                var dislikeCount = document.data()?["dislikeCount"] as? Int ?? 0
                var userVotes = document.data()?["userVotes"] as? [String: String] ?? [:]

                let previousVote = userVotes[userId]

                // Remove previous vote count
                if previousVote == "like" {
                    likeCount -= 1
                } else if previousVote == "dislike" {
                    dislikeCount -= 1
                }

                // Add new vote count
                if voteType == "like" {
                    likeCount += 1
                    userVotes[userId] = "like"
                } else if voteType == "dislike" {
                    dislikeCount += 1
                    userVotes[userId] = "dislike"
                } else {
                    userVotes.removeValue(forKey: userId)
                }

                transaction.setData([
                    "likeCount": likeCount,
                    "dislikeCount": dislikeCount,
                    "userVotes": userVotes
                ], forDocument: docRef, merge: true)

                return nil
            }

            // Reload votes after transaction
            await loadVotes(for: date)

        } catch {
            print("Error voting: \(error.localizedDescription)")
        }
    }
}

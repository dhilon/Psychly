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

    // SF Symbol pool organized by category
    private let iconPool: [String: [String]] = [
        "social": ["person.2.fill", "person.3.fill", "figure.2", "person.wave.2.fill"],
        "cognitive": ["brain.head.profile", "brain", "lightbulb.fill", "puzzlepiece.fill"],
        "behavioral": ["pawprint.fill", "bell.fill", "arrow.triangle.branch", "repeat"],
        "memory": ["memorychip", "doc.text.fill", "list.clipboard.fill", "tray.full.fill"],
        "emotional": ["heart.fill", "face.smiling.fill", "bolt.heart.fill", "heart.circle.fill"],
        "developmental": ["figure.and.child.holdinghands", "figure.2.and.child.holdinghands", "leaf.fill", "sparkles"],
        "perception": ["eye.fill", "ear.fill", "hand.raised.fill", "camera.metering.spot"],
        "obedience": ["figure.stand.line.dotted.figure.stand", "hand.raised.slash.fill", "exclamationmark.triangle.fill", "bolt.shield.fill"],
        "conformity": ["person.3.sequence.fill", "arrow.left.arrow.right", "equal.circle.fill", "circle.grid.3x3.fill"],
        "learning": ["book.fill", "graduationcap.fill", "pencil.and.outline", "text.book.closed.fill"],
        "aggression": ["bolt.fill", "flame.fill", "burst.fill", "waveform.path.ecg"],
        "attachment": ["link.circle.fill", "figure.2.arms.open", "hands.clap.fill", "gift.fill"],
        "motivation": ["flag.fill", "star.fill", "trophy.fill", "target"],
        "stress": ["waveform.path.ecg.rectangle.fill", "exclamationmark.circle.fill", "cloud.bolt.fill", "tornado"],
        "default": ["flask.fill", "testtube.2", "atom", "questionmark.circle.fill", "magnifyingglass"]
    ]

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

                // Check if this is an old experiment with "question" but no "hypothesis"
                if data["question"] != nil && data["hypothesis"] == nil {
                    print("🔵 Migrating old experiment to new format...")
                    await migrateExperiment(documentId: dateStr, data: data)
                } else {
                    var loadedExperiment = Experiment(
                        name: data["name"] as? String ?? "",
                        info: data["info"] as? String ?? "",
                        date: data["date"] as? String ?? "",
                        researchers: data["researchers"] as? String ?? "",
                        hypothesis: data["hypothesis"] as? String ?? "",
                        rejected: data["rejected"] as? Bool ?? false,
                        badgeIcon: data["badgeIcon"] as? String,
                        badgeCategory: data["badgeCategory"] as? String
                    )

                    // Migrate badge if missing
                    if loadedExperiment.badgeIcon == nil {
                        print("🔵 Migrating badge for experiment: \(loadedExperiment.name)")
                        await migrateBadge(documentId: dateStr, experiment: &loadedExperiment)
                    }

                    experiment = loadedExperiment
                }
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
            var newExperiment = try await GeminiService.shared.getRandomExperiment(excludingNames: existingNames)
            print("🟢 Got experiment from Gemini: \(newExperiment.name)")

            // Generate unique badge icon
            let usedIcons = try await getUsedBadgeIcons()
            let category = try await GeminiService.shared.categorizeExperiment(name: newExperiment.name, info: newExperiment.info)
            let badgeIcon = selectUniqueBadgeIcon(category: category, usedIcons: usedIcons)
            print("🔵 Selected badge icon: \(badgeIcon) for category: \(category)")

            newExperiment.badgeIcon = badgeIcon
            newExperiment.badgeCategory = category

            // Save to Firestore
            let dateStr = dateString(from: date)
            print("🔵 Saving to Firestore with date: \(dateStr)")

            let experimentData: [String: Any] = [
                "name": newExperiment.name,
                "info": newExperiment.info,
                "date": newExperiment.date,
                "researchers": newExperiment.researchers,
                "hypothesis": newExperiment.hypothesis,
                "rejected": newExperiment.rejected,
                "badgeIcon": badgeIcon,
                "badgeCategory": category
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

    private func getUsedBadgeIcons() async throws -> Set<String> {
        let snapshot = try await db.collection("experiments").getDocuments()
        let icons = snapshot.documents.compactMap { $0.data()["badgeIcon"] as? String }
        return Set(icons)
    }

    private func selectUniqueBadgeIcon(category: String, usedIcons: Set<String>) -> String {
        // 1. Try category-specific icons first
        if let categoryIcons = iconPool[category] {
            if let available = categoryIcons.first(where: { !usedIcons.contains($0) }) {
                return available
            }
        }

        // 2. Fall back to any unused icon from any category
        for (_, icons) in iconPool {
            if let available = icons.first(where: { !usedIcons.contains($0) }) {
                return available
            }
        }

        // 3. Last resort: use a generic icon (shouldn't happen with 50+ icons)
        return "circle.fill"
    }

    private func migrateBadge(documentId: String, experiment: inout Experiment) async {
        do {
            let usedIcons = try await getUsedBadgeIcons()
            let category = try await GeminiService.shared.categorizeExperiment(name: experiment.name, info: experiment.info)
            let badgeIcon = selectUniqueBadgeIcon(category: category, usedIcons: usedIcons)

            // Update Firestore
            try await db.collection("experiments").document(documentId).updateData([
                "badgeIcon": badgeIcon,
                "badgeCategory": category
            ])

            experiment.badgeIcon = badgeIcon
            experiment.badgeCategory = category
            print("🟢 Migrated badge for \(experiment.name): \(badgeIcon)")
        } catch {
            print("🔴 Error migrating badge: \(error.localizedDescription)")
            // Use default badge on error
            experiment.badgeIcon = "flask.fill"
            experiment.badgeCategory = "default"
        }
    }

    private func migrateExperiment(documentId: String, data: [String: Any]) async {
        let name = data["name"] as? String ?? ""
        let info = data["info"] as? String ?? ""

        do {
            // Get hypothesis and rejected from Gemini
            let (hypothesis, rejected) = try await GeminiService.shared.generateHypothesisForExperiment(name: name, info: info)

            // Update Firestore with new fields
            try await db.collection("experiments").document(documentId).updateData([
                "hypothesis": hypothesis,
                "rejected": rejected
            ])

            // Optionally remove old question field
            try await db.collection("experiments").document(documentId).updateData([
                "question": FieldValue.delete()
            ])

            print("🟢 Successfully migrated experiment: \(name)")

            // Set the experiment with new data
            experiment = Experiment(
                name: name,
                info: info,
                date: data["date"] as? String ?? "",
                researchers: data["researchers"] as? String ?? "",
                hypothesis: hypothesis,
                rejected: rejected
            )
        } catch {
            print("🔴 Error migrating experiment: \(error.localizedDescription)")
            // Fallback: use empty hypothesis
            experiment = Experiment(
                name: name,
                info: info,
                date: data["date"] as? String ?? "",
                researchers: data["researchers"] as? String ?? "",
                hypothesis: data["question"] as? String ?? "",
                rejected: false
            )
        }
    }
}

//
//  TheoryManager.swift
//  Psychly
//
//  Created by Dhilon Prasad on 2/6/26.
//

import Foundation
import FirebaseFirestore

@MainActor
class TheoryManager: ObservableObject {
    @Published var theory: Theory? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()

    // SF Symbol pool organized by category for theories
    private let iconPool: [String: [String]] = [
        "social": ["person.2.fill", "person.3.fill", "figure.2", "person.wave.2.fill"],
        "cognitive": ["brain.head.profile", "brain", "lightbulb.fill", "puzzlepiece.fill"],
        "behavioral": ["pawprint.fill", "bell.fill", "arrow.triangle.branch", "repeat"],
        "developmental": ["figure.and.child.holdinghands", "figure.2.and.child.holdinghands", "leaf.fill", "sparkles"],
        "emotional": ["heart.fill", "face.smiling.fill", "bolt.heart.fill", "heart.circle.fill"],
        "personality": ["person.crop.circle.fill", "theatermasks.fill", "star.circle.fill", "crown.fill"],
        "learning": ["book.fill", "graduationcap.fill", "pencil.and.outline", "text.book.closed.fill"],
        "motivation": ["flag.fill", "star.fill", "trophy.fill", "target"],
        "attachment": ["link.circle.fill", "figure.2.arms.open", "hands.clap.fill", "gift.fill"],
        "humanistic": ["sun.max.fill", "sparkle", "arrow.up.circle.fill", "rays"],
        "psychodynamic": ["moon.fill", "cloud.fill", "eye.slash.fill", "waveform"],
        "biological": ["brain.fill", "dna.helix", "heart.text.square.fill", "stethoscope"],
        "default": ["lightbulb.fill", "questionmark.circle.fill", "magnifyingglass", "book.closed.fill"]
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

    func loadTheory(for date: Date) async {
        isLoading = true
        errorMessage = nil

        let dateStr = dateString(from: date)
        print("🔵 Loading theory for date: \(dateStr)")
        print("🔵 Is today: \(isToday(date))")

        do {
            // Check if theory exists for this date
            let document = try await db.collection("theories").document(dateStr).getDocument()
            print("🔵 Theory document exists: \(document.exists)")

            if let data = document.data() {
                print("🟢 Found existing theory: \(data)")

                var loadedTheory = Theory(
                    name: data["name"] as? String ?? "",
                    info: data["info"] as? String ?? "",
                    yearCreated: data["yearCreated"] as? String ?? "",
                    theorists: data["theorists"] as? String ?? "",
                    badgeIcon: data["badgeIcon"] as? String,
                    badgeCategory: data["badgeCategory"] as? String
                )

                // Migrate badge if missing
                if loadedTheory.badgeIcon == nil {
                    print("🔵 Migrating badge for theory: \(loadedTheory.name)")
                    await migrateBadge(documentId: dateStr, theory: &loadedTheory)
                }

                theory = loadedTheory
            } else if isToday(date) {
                print("🔵 No theory for today, fetching from Gemini...")
                // No theory for today, fetch from Gemini
                await fetchNewTheory(for: date)
            } else {
                print("🟡 Past date with no theory")
                // Past date with no theory
                theory = nil
            }
        } catch {
            print("🔴 Error loading theory: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchNewTheory(for date: Date) async {
        do {
            // Get list of existing theory names to exclude
            let existingNames = try await getExistingTheoryNames()
            print("🔵 Existing theory names to exclude: \(existingNames)")

            // Fetch new theory from Gemini
            print("🔵 Calling Gemini API for theory...")
            var newTheory = try await GeminiService.shared.getRandomTheory(excludingNames: existingNames)
            print("🟢 Got theory from Gemini: \(newTheory.name)")

            // Generate unique badge icon
            let usedIcons = try await getUsedBadgeIcons()
            let category = try await GeminiService.shared.categorizeTheory(name: newTheory.name, info: newTheory.info)
            let badgeIcon = selectUniqueBadgeIcon(category: category, usedIcons: usedIcons)
            print("🔵 Selected badge icon: \(badgeIcon) for category: \(category)")

            newTheory.badgeIcon = badgeIcon
            newTheory.badgeCategory = category

            // Save to Firestore
            let dateStr = dateString(from: date)
            print("🔵 Saving theory to Firestore with date: \(dateStr)")

            let theoryData: [String: Any] = [
                "name": newTheory.name,
                "info": newTheory.info,
                "yearCreated": newTheory.yearCreated,
                "theorists": newTheory.theorists,
                "badgeIcon": badgeIcon,
                "badgeCategory": category
            ]
            print("🔵 Theory data to save: \(theoryData)")

            try await db.collection("theories").document(dateStr).setData(theoryData)
            print("🟢 Successfully saved theory to Firestore")

            theory = newTheory
            print("🟢 Theory set in manager")
        } catch {
            print("🔴 Error in fetchNewTheory: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    private func getExistingTheoryNames() async throws -> [String] {
        let snapshot = try await db.collection("theories").getDocuments()
        return snapshot.documents.compactMap { $0.data()["name"] as? String }
    }

    private func getUsedBadgeIcons() async throws -> Set<String> {
        let snapshot = try await db.collection("theories").getDocuments()
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

        // 3. Last resort: use a generic icon
        return "lightbulb.fill"
    }

    private func migrateBadge(documentId: String, theory: inout Theory) async {
        do {
            let usedIcons = try await getUsedBadgeIcons()
            let category = try await GeminiService.shared.categorizeTheory(name: theory.name, info: theory.info)
            let badgeIcon = selectUniqueBadgeIcon(category: category, usedIcons: usedIcons)

            // Update Firestore
            try await db.collection("theories").document(documentId).updateData([
                "badgeIcon": badgeIcon,
                "badgeCategory": category
            ])

            theory.badgeIcon = badgeIcon
            theory.badgeCategory = category
            print("🟢 Migrated badge for theory \(theory.name): \(badgeIcon)")
        } catch {
            print("🔴 Error migrating badge: \(error.localizedDescription)")
            // Use default badge on error
            theory.badgeIcon = "lightbulb.fill"
            theory.badgeCategory = "default"
        }
    }
}

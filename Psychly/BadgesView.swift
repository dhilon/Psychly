//
//  BadgesView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/29/26.
//

import SwiftUI
import FirebaseFirestore

struct Badge: Identifiable {
    let id: String // date string
    let experimentName: String
    let badgeIcon: String
    let badgeCategory: String
}

@MainActor
class BadgesManager: ObservableObject {
    @Published var badges: [Badge] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func loadBadges(correctDates: [String]) async {
        isLoading = true
        var loadedBadges: [Badge] = []

        for dateStr in correctDates {
            do {
                let document = try await db.collection("experiments").document(dateStr).getDocument()
                if let data = document.data() {
                    let badge = Badge(
                        id: dateStr,
                        experimentName: data["name"] as? String ?? "Unknown Experiment",
                        badgeIcon: data["badgeIcon"] as? String ?? "flask.fill",
                        badgeCategory: data["badgeCategory"] as? String ?? "default"
                    )
                    loadedBadges.append(badge)
                }
            } catch {
                print("🔴 Error loading badge for \(dateStr): \(error.localizedDescription)")
            }
        }

        // Sort by date (most recent first)
        badges = loadedBadges.sorted { $0.id > $1.id }
        isLoading = false
    }
}

struct BadgesView: View {
    let correctDates: [String]
    @StateObject private var badgesManager = BadgesManager()
    @State private var selectedBadge: Badge? = nil

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            if badgesManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading badges...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else if badgesManager.badges.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No Badges Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Answer experiments correctly to earn badges!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .padding()
            } else {
                VStack(spacing: 24) {
                    // Badge count
                    Text("\(badgesManager.badges.count) Badge\(badgesManager.badges.count == 1 ? "" : "s") Earned")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)

                    // Selected badge name display
                    if let selected = selectedBadge {
                        Text(selected.experimentName)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Tap a badge to see its name")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }

                    // Badges grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(badgesManager.badges) { badge in
                            BadgeCell(
                                badge: badge,
                                isSelected: selectedBadge?.id == badge.id
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedBadge?.id == badge.id {
                                        selectedBadge = nil
                                    } else {
                                        selectedBadge = badge
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await badgesManager.loadBadges(correctDates: correctDates)
        }
    }
}

struct BadgeCell: View {
    let badge: Badge
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.green : Color.green.opacity(0.8))
                .shadow(color: isSelected ? .green.opacity(0.5) : .clear, radius: 8)

            Image(systemName: badge.badgeIcon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
        }
        .frame(width: 70, height: 70)
        .scaleEffect(isSelected ? 1.15 : 1.0)
    }
}

#Preview {
    NavigationStack {
        BadgesView(correctDates: ["2026-01-28", "2026-01-27", "2026-01-26"])
    }
}

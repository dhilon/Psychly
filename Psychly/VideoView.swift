//
//  VideoView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI
import UIKit

struct VideoView: View {
    let date: Date
    @StateObject private var voteManager = VoteManager()
    @StateObject private var experimentManager = ExperimentManager()
    @State private var frames: [UIImage] = []
    @State private var isLoadingAnimation = true
    @State private var animationFailed = false
    @State private var generationProgress: Int = 0
    @State private var totalFrames: Int = 50

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animation or fallback stick figures
            if isLoadingAnimation {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    if generationProgress > 0 {
                        Text("Generating frame \(generationProgress)/\(totalFrames)...")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        ProgressView(value: Double(generationProgress), total: Double(totalFrames))
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                    } else {
                        Text("Loading animation...")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
            } else if animationFailed || frames.isEmpty {
                // Fallback to static stick figures
                StickFiguresView()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                // Animated frames
                AnimatedExperimentView(frames: frames)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
            }

            // Like and Dislike buttons
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Button {
                        Task {
                            let newVote = voteManager.userVote == "dislike" ? nil : "dislike"
                            await voteManager.vote(for: date, voteType: newVote)
                        }
                    } label: {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(voteManager.userVote == "dislike" ? .gray : .red.opacity(0.8))
                            .frame(width: 70, height: 70)
                            .background(voteManager.userVote == "dislike" ? Color.purple : Color(.systemGray6))
                            .cornerRadius(35)
                    }
                    .disabled(voteManager.isLoading)

                    Text("\(voteManager.dislikeCount)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Button {
                        Task {
                            let newVote = voteManager.userVote == "like" ? nil : "like"
                            await voteManager.vote(for: date, voteType: newVote)
                        }
                    } label: {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(voteManager.userVote == "like" ? .gray : .green.opacity(0.8))
                            .frame(width: 70, height: 70)
                            .background(voteManager.userVote == "like" ? Color.purple : Color(.systemGray6))
                            .cornerRadius(35)
                    }
                    .disabled(voteManager.isLoading)

                    Text("\(voteManager.likeCount)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await voteManager.loadVotes(for: date)
            await loadAnimation()
        }
    }

    private func loadAnimation() async {
        // 1. Load experiment data
        await experimentManager.loadExperiment(for: date)

        guard let experiment = experimentManager.experiment else {
            print("🔴 No experiment found for animation")
            animationFailed = true
            isLoadingAnimation = false
            return
        }

        // 2. Check cache first
        if let cached = await GIFGenerationService.shared.getCachedFrames(
            experimentDate: dateString,
            experimentName: experiment.name
        ) {
            print("🟢 Using cached frames")
            frames = cached
            isLoadingAnimation = false
            return
        }

        // 3. Generate new frames with progress updates
        do {
            print("🔵 Generating 50 frames for: \(experiment.name)")
            let generatedFrames = try await GIFGenerationService.shared.generateExperimentFrames(
                experiment: experiment,
                onProgress: { current, total in
                    Task { @MainActor in
                        generationProgress = current
                        totalFrames = total
                    }
                }
            )
            frames = generatedFrames

            // 4. Cache frames for future use
            do {
                try await GIFGenerationService.shared.cacheFrames(
                    frames: generatedFrames,
                    experimentDate: dateString,
                    experimentName: experiment.name
                )
            } catch {
                print("🟡 Failed to cache frames: \(error.localizedDescription)")
            }

            isLoadingAnimation = false
        } catch {
            print("🔴 Failed to generate animation: \(error.localizedDescription)")
            animationFailed = true
            isLoadingAnimation = false
        }
    }
}

#Preview {
    NavigationStack {
        VideoView(date: Date())
    }
}

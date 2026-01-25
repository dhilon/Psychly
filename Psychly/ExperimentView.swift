//
//  ExperimentView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct ExperimentView: View {
    let date: Date
    @StateObject private var voteManager = VoteManager()
    @StateObject private var experimentManager = ExperimentManager()
    @StateObject private var userStatsManager = UserStatsManager()
    @State private var showHint = false
    @State private var userGuess = ""
    @State private var hasSubmittedGuess = false
    @State private var isCheckingGuess = false
    @State private var guessWasCorrect: Bool? = nil
    @State private var incorrectReasoning: String? = nil

    private var isToday: Bool {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        return todayComponents.year == dateComponents.year &&
               todayComponents.month == dateComponents.month &&
               todayComponents.day == dateComponents.day
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Experiment for \(formattedDate)")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.top, 24)

                if experimentManager.isLoading {
                    ProgressView("Loading experiment...")
                        .padding(.top, 40)
                } else if let experiment = experimentManager.experiment {
                    // Experiment info box
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isToday ? "Mystery Experiment" : experiment.name)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)

                        Text(experiment.info)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)

                        Divider()

                        Text("Hypothesis")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(experiment.hypothesis)
                            .font(.system(.body, design: .rounded))
                            .italic()
                            .foregroundStyle(.purple)

                        // For past dates, show all info directly
                        if !isToday {
                            Divider()

                            HStack {
                                Text("Date:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(experiment.date)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                            }

                            HStack {
                                Text("Researchers:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(experiment.researchers)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                            }

                            HStack {
                                Text("Hypothesis was:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(experiment.rejected ? "Rejected ✗" : "Supported ✓")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(experiment.rejected ? .red : .green)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                    // Guess input section - only for today
                    if isToday {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What experiment is this?")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)

                            TextField("Enter your guess...", text: $userGuess)
                                .font(.system(.body, design: .rounded))
                                .textFieldStyle(.roundedBorder)
                                .disabled(hasSubmittedGuess)

                            if !hasSubmittedGuess {
                                Button {
                                    Task {
                                        isCheckingGuess = true
                                        do {
                                            let result = try await GeminiService.shared.checkGuess(
                                                userGuess: userGuess,
                                                actualName: experiment.name
                                            )
                                            guessWasCorrect = result.isCorrect
                                            incorrectReasoning = result.reasoning
                                            if !result.isCorrect {
                                                print("🔴 Incorrect guess. Reasoning: \(result.reasoning ?? "No reasoning provided")")
                                            }
                                        } catch {
                                            print("🔴 Error checking guess: \(error)")
                                            guessWasCorrect = false
                                        }
                                        isCheckingGuess = false
                                        withAnimation {
                                            hasSubmittedGuess = true
                                        }
                                        // Record view and update stats when guess is submitted
                                        await userStatsManager.recordView(for: date)
                                    }
                                } label: {
                                    if isCheckingGuess {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.purple)
                                            .cornerRadius(12)
                                    } else {
                                        Text("Submit Guess")
                                            .font(.system(.body, design: .rounded))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(userGuess.isEmpty ? Color.gray : Color.purple)
                                            .cornerRadius(12)
                                    }
                                }
                                .disabled(userGuess.isEmpty || isCheckingGuess)
                            } else {
                                // Show the result after guessing
                                VStack(alignment: .leading, spacing: 12) {
                                    // Correct/Incorrect feedback
                                    HStack {
                                        Image(systemName: guessWasCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(guessWasCorrect == true ? .green : .red)
                                        Text(guessWasCorrect == true ? "Correct!" : "Incorrect")
                                            .font(.system(.headline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundStyle(guessWasCorrect == true ? .green : .red)
                                    }

                                    Divider()

                                    HStack {
                                        Text("Answer:")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Text(experiment.name)
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundStyle(.purple)
                                    }

                                    HStack {
                                        Text("Hypothesis was:")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Text(experiment.rejected ? "Rejected ✗" : "Supported ✓")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundStyle(experiment.rejected ? .red : .green)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Video button (and Hint button only for today)
                    HStack(spacing: 12) {
                        NavigationLink(destination: VideoView()) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Video")
                                    .fontWeight(.semibold)
                            }
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }

                        if isToday {
                            Button {
                                withAnimation {
                                    showHint.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: showHint ? "lightbulb.fill" : "lightbulb")
                                    Text("Hint")
                                        .fontWeight(.semibold)
                                }
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(showHint ? Color.purple : Color.blue)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Hint reveal - only for today
                    if isToday && showHint {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Date:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(experiment.date)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                            }
                            HStack {
                                Text("Researchers:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(experiment.researchers)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } else {
                    // No experiment available
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray)

                        Text("No experiment available for this date")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                }

                // Like and Dislike buttons (only show if experiment exists)
                if experimentManager.experiment != nil {
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
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
        .navigationTitle("Experiment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await experimentManager.loadExperiment(for: date)
            await voteManager.loadVotes(for: date)
            await userStatsManager.loadStats()
        }
    }
}

struct StickFiguresView: View {
    var body: some View {
        Canvas { context, size in
            let figureHeight: CGFloat = 100
            let figureWidth: CGFloat = 50
            let spacing: CGFloat = 60
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Left figure (facing right)
            drawStickFigure(
                context: context,
                centerX: centerX - spacing,
                centerY: centerY,
                figureHeight: figureHeight,
                figureWidth: figureWidth,
                facingRight: true
            )

            // Right figure (facing left)
            drawStickFigure(
                context: context,
                centerX: centerX + spacing,
                centerY: centerY,
                figureHeight: figureHeight,
                figureWidth: figureWidth,
                facingRight: false
            )
        }
    }

    private func drawStickFigure(context: GraphicsContext, centerX: CGFloat, centerY: CGFloat, figureHeight: CGFloat, figureWidth: CGFloat, facingRight: Bool) {
        let headRadius: CGFloat = 12
        let bodyLength: CGFloat = 35
        let legLength: CGFloat = 30
        let armLength: CGFloat = 25

        let headCenterY = centerY - figureHeight / 2 + headRadius
        let neckY = headCenterY + headRadius
        let bodyEndY = neckY + bodyLength
        let eyeOffsetX: CGFloat = facingRight ? 4 : -4

        let strokeColor = Color.gray
        var strokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)

        // Head
        let headPath = Path(ellipseIn: CGRect(
            x: centerX - headRadius,
            y: headCenterY - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))
        context.stroke(headPath, with: .color(strokeColor), lineWidth: 3)

        // Eye (small dot)
        let eyePath = Path(ellipseIn: CGRect(
            x: centerX + eyeOffsetX - 2,
            y: headCenterY - 2,
            width: 4,
            height: 4
        ))
        context.fill(eyePath, with: .color(strokeColor))

        // Body
        var bodyPath = Path()
        bodyPath.move(to: CGPoint(x: centerX, y: neckY))
        bodyPath.addLine(to: CGPoint(x: centerX, y: bodyEndY))
        context.stroke(bodyPath, with: .color(strokeColor), lineWidth: 3)

        // Arms
        var armsPath = Path()
        let armY = neckY + 10
        armsPath.move(to: CGPoint(x: centerX - armLength, y: armY + 15))
        armsPath.addLine(to: CGPoint(x: centerX, y: armY))
        armsPath.addLine(to: CGPoint(x: centerX + armLength, y: armY + 15))
        context.stroke(armsPath, with: .color(strokeColor), lineWidth: 3)

        // Legs
        var legsPath = Path()
        legsPath.move(to: CGPoint(x: centerX - 15, y: bodyEndY + legLength))
        legsPath.addLine(to: CGPoint(x: centerX, y: bodyEndY))
        legsPath.addLine(to: CGPoint(x: centerX + 15, y: bodyEndY + legLength))
        context.stroke(legsPath, with: .color(strokeColor), lineWidth: 3)
    }
}

#Preview {
    NavigationStack {
        ExperimentView(date: Date())
    }
}

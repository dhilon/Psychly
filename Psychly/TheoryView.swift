//
//  TheoryView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 2/6/26.
//

import SwiftUI

struct TheoryView: View {
    let date: Date
    @StateObject private var theoryManager = TheoryManager()
    @StateObject private var userStatsManager = UserStatsManager()
    @State private var showHint = false
    @State private var userGuess = ""
    @State private var isCheckingGuess = false
    @State private var incorrectReasoning: String? = nil
    @State private var statsLoaded = false

    // Computed properties from persisted state
    private var hasSubmittedGuess: Bool {
        userStatsManager.hasAnsweredTheory(for: date)
    }

    private var guessWasCorrect: Bool? {
        userStatsManager.getTheoryAnswer(for: date)?.correct
    }

    private var previousGuess: String? {
        userStatsManager.getTheoryAnswer(for: date)?.guess
    }

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
                Text("Theory for \(formattedDate)")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.top, 24)

                if theoryManager.isLoading {
                    ProgressView("Loading theory...")
                        .padding(.top, 40)
                } else if let theory = theoryManager.theory {
                    // Theory info box
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isToday ? "Mystery Theory" : theory.name)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)

                        Text(theory.info)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)

                        // For past dates, show all info directly
                        if !isToday {
                            Divider()

                            HStack {
                                Text("Year Created:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(theory.yearCreated)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                            }

                            HStack {
                                Text("Theorists:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(theory.theorists)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
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
                            Text("What theory is this?")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)

                            if !statsLoaded {
                                // Loading state while checking if user already answered
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if hasSubmittedGuess {
                                // User already answered - show their guess
                                if let guess = previousGuess {
                                    Text("Your guess: \(guess)")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }

                                // Show the result
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
                                        Text(theory.name)
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundStyle(.purple)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            } else {
                                // User hasn't answered yet - show input
                                TextField("Enter your guess...", text: $userGuess)
                                    .font(.system(.body, design: .rounded))
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    Task {
                                        isCheckingGuess = true
                                        var isCorrect = false
                                        do {
                                            let result = try await GeminiService.shared.checkTheoryGuess(
                                                userGuess: userGuess,
                                                actualName: theory.name
                                            )
                                            isCorrect = result.isCorrect
                                            incorrectReasoning = result.reasoning
                                            if !result.isCorrect {
                                                print("🔴 Incorrect guess. Reasoning: \(result.reasoning ?? "No reasoning provided")")
                                            }
                                        } catch {
                                            print("🔴 Error checking guess: \(error)")
                                            isCorrect = false
                                        }
                                        // Record answer (persists the result)
                                        await userStatsManager.recordTheoryAnswer(for: date, correct: isCorrect, guess: userGuess)
                                        isCheckingGuess = false
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
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Hint button only for today (no video button for theories)
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
                        .padding(.horizontal, 24)
                    }

                    // Hint reveal - only for today
                    if isToday && showHint {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Year Created:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(theory.yearCreated)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                            }
                            HStack {
                                Text("Theorists:")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(theory.theorists)
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
                    // No theory available
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray)

                        Text("No theory available for this date")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                }

                Spacer()
            }
        }
        .navigationTitle("Theory")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await theoryManager.loadTheory(for: date)
            await userStatsManager.loadStats()
            statsLoaded = true
        }
    }
}

#Preview {
    NavigationStack {
        TheoryView(date: Date())
    }
}

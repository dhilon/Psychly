//
//  HomeView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct HomeView: View {
    @State private var randomNumber: Int? = nil
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome header
                    VStack(spacing: 8) {
                        Text("Welcome to")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("Psychly")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 40)

                    // App icon
                    Image(systemName: "brain.head.profile")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundStyle(.purple)
                        .padding(.vertical, 20)

                    // Welcome message card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your daily psych knowledge check")
                            .font(.headline)

                        Text("Experience some of the most fascinating and unique studies and experiments in human history. Understand the evolution of methods and results.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Spacer()

                    // Random number from Gemini
                    VStack(spacing: 8) {
                        Text("Gemini's Random Number")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)

                        if isLoading {
                            ProgressView()
                                .frame(width: 60, height: 60)
                        } else if let number = randomNumber {
                            Text("\(number)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.purple)
                        } else {
                            Text("--")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await fetchRandomNumber()
            }
        }
    }

    private func fetchRandomNumber() async {
        isLoading = true
        do {
            randomNumber = try await GeminiService.shared.getRandomNumber()
        } catch {
            print("Error fetching random number: \(error.localizedDescription)")
            randomNumber = nil
        }
        isLoading = false
    }
}

#Preview {
    HomeView()
}

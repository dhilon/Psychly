//
//  ProfileView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Profile icon
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.gray)

                Text("Your Profile")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Stats boxes
                HStack(spacing: 12) {
                    StatBox(icon: "globe.americas.fill", value: "#1,234", label: "World Rank")
                    StatBox(icon: "checkmark.circle.fill", value: "42", label: "Days Achieved")
                    StatBox(icon: "flame.fill", value: "7", label: "Streak")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Logout button
                Button(role: .destructive) {
                    authManager.signOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatBox: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)

            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
}

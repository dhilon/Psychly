//
//  SignupView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showErrorAlert = false

    var onTransitionLogin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Logo/App name
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.blue)

                Text("Psychly")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding(.bottom, 40)

            // Email TextField
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Enter your email", text: $email)
                    .textFieldStyle(.plain)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }

            // Password SecureField
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    if isPasswordVisible {
                        TextField("Enter your password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                    }

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }

            // Sign Up Button
            Button {
                Task {
                    do {
                        try await authManager.signUp(email: email, password: password)
                    } catch {
                        showErrorAlert = true
                    }
                }
            } label: {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                } else {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
            .padding(.top, 10)

            Spacer()

            // Sign Up link
            HStack {
                Text("Already have an account?")
                    .foregroundStyle(.secondary)

                Button {
                    onTransitionLogin()
                } label: {
                    Text("Log In")
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 30)
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                authManager.errorMessage = nil
            }
        } message: {
            Text(authManager.errorMessage ?? "An error occurred")
        }
    }
}

#Preview {
    SignupView(onTransitionLogin: {})
        .environmentObject(AuthenticationManager())
}

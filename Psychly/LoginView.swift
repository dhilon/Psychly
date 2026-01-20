//
//  LoginView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    var onLoginSuccess: () -> Void
    var onTransitionSignup: () -> Void

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

            // Sign In Button
            Button {
                // Placeholder - no backend integration
                onLoginSuccess()
            } label: {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 10)

            // Divider with "or"
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color(.systemGray4))

                Text("or")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)

                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color(.systemGray4))
            }
            .padding(.vertical, 10)

            // Sign in with Apple Button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                // Placeholder - no backend integration
                switch result {
                case .success:
                    onLoginSuccess()
                case .failure(let error):
                    print("Sign in with Apple failed: \(error.localizedDescription)")
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)

            Spacer()

            // Sign Up link
            HStack {
                Text("Don't have an account?")
                    .foregroundStyle(.secondary)

                Button {
                    onTransitionSignup()
                } label: {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 30)
    }
}

#Preview {
    LoginView(onLoginSuccess: {}, onTransitionSignup: {})
}

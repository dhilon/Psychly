//
//  ContentView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var showSignUp = false

    var body: some View {
        if isLoggedIn {
            MainTabView {
                isLoggedIn = false
            }
        } else if showSignUp {
            SignupView(
                onSignupSuccess: { isLoggedIn = true },
                onTransitionLogin: { showSignUp = false }
            )
        } else {
            LoginView(
                onLoginSuccess: { isLoggedIn = true },
                onTransitionSignup: { showSignUp = true }
            )
        }
    }
}

#Preview {
    ContentView()
}

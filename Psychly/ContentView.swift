//
//  ContentView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showSignUp = false

    var body: some View {
        if authManager.isAuthenticated {
            MainTabView()
        } else if showSignUp {
            SignupView(onTransitionLogin: { showSignUp = false })
        } else {
            LoginView(onTransitionSignup: { showSignUp = true })
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}

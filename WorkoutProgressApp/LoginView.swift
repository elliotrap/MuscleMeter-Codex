//
//  LoginView.swift
//  WorkoutProgressApp
//
//  Created by Elliot Rapp on 2/10/25.
//
import CloudKit
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Binding var isAuthenticated: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Please sign in to continue")
                .font(.headline)
            
            SignInWithAppleButton(
                onRequest: { request in
                    // Request full name and email if needed.
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        // You can extract the credential and verify it if needed.
                        print("Authorization successful: \(authResults)")
                        DispatchQueue.main.async {
                            self.isAuthenticated = true
                        }
                    case .failure(let error):
                        print("Authorization failed: \(error.localizedDescription)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .padding(.horizontal)
        }
        .padding()
    }
}

//
//  LoginView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Text("Portfolio Tracker")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Login or register to enter the portfolio.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 14) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                SecureField("Password (Optional)", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            Button(action: login) {
                Text("Login / Register")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Spacer()
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func login() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }
        
        let descriptor = FetchDescriptor<User>()
        if let existingUser = try? modelContext.fetch(descriptor).first {
            if existingUser.username.isEmpty {
                existingUser.username = trimmedUsername
            }
            if existingUser.passwordHash.isEmpty {
                existingUser.passwordHash = password.isEmpty ? "dummy" : password
            }
            try? modelContext.save()
            return
        }
        
        let user = User(username: trimmedUsername, passwordHash: password.isEmpty ? "dummy" : password)
        modelContext.insert(user)
        try? modelContext.save()
    }
}

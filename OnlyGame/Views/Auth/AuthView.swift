import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email      = ""
    @State private var password   = ""
    @State private var username   = ""
    @State private var isSignUp   = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                brandingSection
                if authVM.awaitingConfirmation {
                    confirmationCard
                } else {
                    formCard
                }
                Spacer()
            }
            .padding(28)

            Button {
                authVM.dismissConfirmation()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .padding(20)
        }
    }

    // MARK: - Subviews

    private var background: some View {
        LinearGradient(
            colors: [.black, .purple.opacity(0.92), .blue.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var brandingSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.95))

            Text("OnlyGame")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)

            Text(isSignUp
                 ? "Create your account to start building your library."
                 : "Sign in to access your library, cart, and achievements.")
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isSignUp {
                fieldBlock(label: "Username", placeholder: "Enter your username", text: $username)
            }

            fieldBlock(label: "Email", placeholder: "Enter your email", text: $email)

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            if !authVM.errorMessage.isEmpty {
                Text(authVM.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        if isSignUp {
                            await authVM.signUp(email: email, password: password, username: username)
                        } else {
                            await authVM.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    Text(authVM.isLoading
                         ? (isSignUp ? "Creating..." : "Signing In...")
                         : (isSignUp ? "Create Account" : "Sign In"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(authVM.isLoading)

                Button {
                    isSignUp.toggle()
                    authVM.errorMessage = ""
                } label: {
                    Text(isSignUp ? "I already have an account" : "Create new account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(authVM.isLoading)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: 460)
    }

    private var confirmationCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)

            VStack(spacing: 8) {
                Text("Check your email")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("We sent a confirmation link to\n\(authVM.pendingConfirmationEmail)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            Text("Click the link in your email, then come back and sign in.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)

            Button {
                authVM.dismissConfirmation()
                isSignUp = false
                email = authVM.pendingConfirmationEmail
            } label: {
                Text("Continue to Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(maxWidth: 460)
    }

    private func fieldBlock(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
        }
    }
}

import SwiftUI

struct SignInRequiredView: View {
    let icon: String
    let message: String
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.28))
                .padding(22)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 24))

            Text(message)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Create a free account or sign in to continue.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)

            Button(action: onSignIn) {
                Text("Sign In")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

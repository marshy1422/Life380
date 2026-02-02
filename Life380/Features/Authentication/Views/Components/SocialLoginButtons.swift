import SwiftUI
import AuthenticationServices

/// Apple Sign In button styled for the app
struct AppleSignInButton: View {
    @Environment(\.colorScheme) var colorScheme

    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            onRequest(request)
        } onCompletion: { result in
            onCompletion(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}

/// Social login divider with "or" text
struct SocialLoginDivider: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(AppTheme.Colors.separator)
                .frame(height: 1)

            Text("or")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.secondaryText)
                .padding(.horizontal, AppTheme.Spacing.sm)

            Rectangle()
                .fill(AppTheme.Colors.separator)
                .frame(height: 1)
        }
    }
}

/// Container for social login options
struct SocialLoginSection: View {
    let nonce: String
    let onAppleSignIn: (ASAuthorization) -> Void
    let onError: (Error) -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SocialLoginDivider()

            AppleSignInButton { request in
                request.requestedScopes = [.fullName, .email]
                request.nonce = nonce
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    onAppleSignIn(authorization)
                case .failure(let error):
                    onError(error)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SocialLoginDivider()

        AppleSignInButton { _ in } onCompletion: { _ in }
    }
    .padding()
}

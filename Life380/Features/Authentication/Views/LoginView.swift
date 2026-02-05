import SwiftUI
import AuthenticationServices
import CoreLocation

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationManager: PrecisionLocationManager
    @Environment(\.colorScheme) var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var isAnimating = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, password
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section with Animated Logo
                        heroSection
                            .frame(height: geometry.size.height * 0.35)

                        // Login Form
                        loginForm
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.top, AppTheme.Spacing.xl)

                        Spacer(minLength: AppTheme.Spacing.xl)

                        // Sign Up Link
                        signUpLink
                            .padding(.bottom, AppTheme.Spacing.xl)
                    }
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(backgroundGradient)
            .ignoresSafeArea(edges: .top)
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    isAnimating = true
                }
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()

            // Animated Logo
            ZStack {
                // Pulsing rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(100 + index * 30), height: CGFloat(100 + index * 30))
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }

                // Main icon
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }

            Text("Life380")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(.white)

            Text("Keep your family connected")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
    }

    // MARK: - Login Form
    private var loginForm: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Email Field
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Email")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    TextField("", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                .padding(AppTheme.Spacing.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .stroke(focusedField == .email ? AppTheme.Colors.primaryGradientStart : .clear, lineWidth: 2)
                )
            }

            // Password Field
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Password")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    SecureField("", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                }
                .padding(AppTheme.Spacing.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .stroke(focusedField == .password ? AppTheme.Colors.primaryGradientStart : .clear, lineWidth: 2)
                )
            }

            // Error Message
            if let error = authService.errorMessage {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.error)
                .padding(AppTheme.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Colors.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                .transition(.scale.combined(with: .opacity))
            }

            // Sign In Button
            Button(action: signIn) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    if authService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
            .padding(.top, AppTheme.Spacing.xs)

            // Forgot Password
            Button("Forgot Password?") {
                showingForgotPassword = true
            }
            .font(AppTheme.Typography.footnote)
            .foregroundStyle(.secondary)

            // Divider
            HStack(spacing: AppTheme.Spacing.md) {
                Rectangle()
                    .fill(.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("or continue with")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, AppTheme.Spacing.md)

            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                guard let nonce = authService.prepareSignInWithApple() else { return }
                request.requestedScopes = [.fullName, .email]
                request.nonce = nonce
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    Task {
                        // Get location for new users (fixes "Null Island" bug)
                        locationManager.requestPermission()
                        locationManager.startTracking()
                        let location = await waitForLocation(timeout: 3.0)

                        await authService.handleSignInWithApple(
                            authorization: authorization,
                            location: location?.coordinate,
                            accuracy: location?.horizontalAccuracy
                        )
                    }
                case .failure(let error):
                    authService.errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.adaptive(for: colorScheme))
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        }
    }

    // MARK: - Sign Up Link
    private var signUpLink: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Text("Don't have an account?")
                .foregroundStyle(.secondary)
            Button("Sign Up") {
                showingSignUp = true
            }
            .fontWeight(.semibold)
            .foregroundStyle(AppTheme.Colors.primaryGradientStart)
        }
        .font(AppTheme.Typography.footnote)
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                AppTheme.Colors.primaryGradientStart,
                AppTheme.Colors.primaryGradientEnd.opacity(0.8),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func signIn() {
        focusedField = nil
        Task {
            await authService.signIn(email: email, password: password)
        }
    }

    /// Wait for location with timeout - returns nil if location not available in time
    private func waitForLocation(timeout: TimeInterval) async -> PrecisionLocation? {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if let location = locationManager.currentLocation,
               location.horizontalAccuracy < 100 {
                return location
            }
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }

        return locationManager.currentLocation
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService())
        .environmentObject(PrecisionLocationManager())
}

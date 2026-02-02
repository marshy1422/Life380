import SwiftUI

/// Reusable text field for authentication forms
struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .never
    var validation: (() -> Bool)?
    var errorMessage: String?

    @State private var isShowingPassword = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.secondaryText)

            HStack {
                Group {
                    if isSecure && !isShowingPassword {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textContentType(textContentType)
                    }
                }
                .textInputAutocapitalization(autocapitalization)
                .focused($isFocused)

                if isSecure {
                    Button {
                        isShowingPassword.toggle()
                    } label: {
                        Image(systemName: isShowingPassword ? "eye.slash" : "eye")
                            .foregroundColor(AppTheme.Colors.secondaryText)
                    }
                }

                if let validation = validation {
                    Image(systemName: validation() ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(validation() ? AppTheme.Colors.success : .clear)
                        .opacity(text.isEmpty ? 0 : 1)
                }
            }
            .padding()
            .background(AppTheme.Colors.secondaryCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .stroke(
                        isFocused ? AppTheme.Colors.primaryGradientStart : Color.clear,
                        lineWidth: 2
                    )
            )

            if let error = errorMessage, !text.isEmpty, validation?() == false {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.error)
            }
        }
    }
}

// MARK: - Convenience Initializers

extension AuthTextField {
    /// Email text field
    static func email(text: Binding<String>, validation: (() -> Bool)? = nil) -> AuthTextField {
        AuthTextField(
            title: "Email",
            placeholder: "Enter your email",
            text: text,
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            validation: validation,
            errorMessage: "Please enter a valid email"
        )
    }

    /// Password text field
    static func password(text: Binding<String>, title: String = "Password", validation: (() -> Bool)? = nil) -> AuthTextField {
        AuthTextField(
            title: title,
            placeholder: "Enter your password",
            text: text,
            isSecure: true,
            textContentType: .password,
            validation: validation,
            errorMessage: "Password must be at least 8 characters"
        )
    }

    /// Name text field
    static func name(text: Binding<String>, validation: (() -> Bool)? = nil) -> AuthTextField {
        AuthTextField(
            title: "Full Name",
            placeholder: "Enter your name",
            text: text,
            textContentType: .name,
            autocapitalization: .words,
            validation: validation,
            errorMessage: "Please enter your name"
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        AuthTextField.email(text: .constant("test@example.com")) { true }
        AuthTextField.password(text: .constant("password123")) { true }
        AuthTextField.name(text: .constant("John Doe")) { true }
    }
    .padding()
}

import SwiftUI

/// Toast notification view
struct ToastView: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void

    enum ToastType {
        case success
        case error
        case warning
        case info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return AppTheme.Colors.success
            case .error: return AppTheme.Colors.error
            case .warning: return AppTheme.Colors.warning
            case .info: return AppTheme.Colors.primaryGradientStart
            }
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)

            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.primaryText)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(AppTheme.Colors.secondaryText)
                    .font(.caption)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

/// Toast modifier for showing toast notifications
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let type: ToastView.ToastType
    let duration: Double

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                VStack {
                    ToastView(message: message, type: type) {
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.md)

                    Spacer()
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation {
                            isPresented = false
                        }
                    }
                }
            }
        }
        .animation(.spring(), value: isPresented)
    }
}

extension View {
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        type: ToastView.ToastType = .info,
        duration: Double = 3.0
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            type: type,
            duration: duration
        ))
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastView(message: "Success!", type: .success) {}
        ToastView(message: "Error occurred", type: .error) {}
        ToastView(message: "Warning!", type: .warning) {}
        ToastView(message: "Info message", type: .info) {}
    }
    .padding()
}

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showPassword = false
    @State private var awaitingEmailConfirmation = false

    enum AuthMode { case signIn, signUp }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Branding
                    VStack(spacing: 8) {
                        Image(systemName: "pawprint.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.snootOrange)
                        Text(mode == .signIn ? "Welcome back" : "Create your account")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.snootBrown)
                        Text(mode == .signIn
                             ? "Sign in to sync your dogs and share care guides"
                             : "Unlock live links, visit logs, and family sharing")
                            .font(.system(size: 15))
                            .foregroundColor(.snootText2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 32)

                    // Form
                    VStack(spacing: 14) {
                        if mode == .signUp {
                            SnootTextField(icon: "person", placeholder: "Display name", text: $displayName)
                        }
                        SnootTextField(icon: "envelope", placeholder: "Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        PasswordField(placeholder: "Password", text: $password, show: $showPassword)
                    }
                    .padding(.horizontal)

                    // Awaiting email confirmation
                    if awaitingEmailConfirmation {
                        VStack(spacing: 6) {
                            Label("Check your email", systemImage: "envelope.badge")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.snootBrown)
                            Text("We sent a confirmation link to \(email). Tap it, then come back and sign in.")
                                .font(.system(size: 13))
                                .foregroundColor(.snootText2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.snootOrange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Error
                    if let err = auth.errorMessage {
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                    }

                    // Primary action
                    Button {
                        Task {
                            awaitingEmailConfirmation = false
                            if mode == .signIn {
                                await auth.signIn(email: email, password: password)
                                if auth.isAuthenticated { dismiss() }
                            } else {
                                await auth.signUp(email: email, password: password, displayName: displayName)
                                if auth.isAuthenticated {
                                    dismiss()
                                } else if auth.errorMessage == nil {
                                    // Supabase returned success but no session → email confirmation required
                                    awaitingEmailConfirmation = true
                                    withAnimation { mode = .signIn }
                                }
                            }
                        }
                    } label: {
                        Group {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(mode == .signIn ? "Sign in" : "Create account")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.snootOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .disabled(auth.isLoading || email.isEmpty || password.isEmpty)

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.2))
                        Text("or").font(.system(size: 14)).foregroundColor(.snootText2)
                        Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.2))
                    }
                    .padding(.horizontal)

                    // Apple Sign In
                    AppleSignInButton()
                        .padding(.horizontal)

                    // Toggle mode
                    Button {
                        withAnimation {
                            mode = mode == .signIn ? .signUp : .signIn
                            auth.errorMessage = nil
                            awaitingEmailConfirmation = false
                        }
                    } label: {
                        Text(mode == .signIn ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                            .font(.system(size: 15))
                            .foregroundColor(.snootOrange)
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(Color.snootCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe later") { dismiss() }
                        .foregroundColor(.snootText2)
                }
            }
        }
    }
}

// MARK: - Apple Sign In button
struct AppleSignInButton: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let hashedNonce = auth.prepareAppleSignIn()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                Task {
                    await auth.handleAppleSignIn(authorization: authorization)
                    if auth.isAuthenticated { await MainActor.run { dismiss() } }
                }
            case .failure:
                break
            }
        }
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}


struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var show: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .foregroundColor(.snootText2)
                .frame(width: 20)
            if show {
                HighContrastTextField(placeholder: placeholder, text: $text)
            } else {
                HighContrastTextField(placeholder: placeholder, text: $text, isSecure: true)
            }
            Button { show.toggle() } label: {
                Image(systemName: show ? "eye.slash" : "eye")
                    .foregroundColor(.snootText2)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.snootDivider, lineWidth: 1.5))
    }
}

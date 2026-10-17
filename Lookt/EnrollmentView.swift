import SwiftUI

struct EnrollmentView: View {
    @AppStorage("isLooktEnabled") private var isLooktEnabled = true
    @AppStorage("unlockMode") private var unlockModeRaw = UnlockMode.autoUnlock.rawValue
    @AppStorage("boostBrightness") private var boostBrightness = true

    @StateObject private var loginItem = LoginItemManager()
    @State private var profiles: [FaceProfile] = []
    @State private var isShowingEnrollmentSheet = false
    @State private var isShowingPasswordSheet = false
    @State private var profileToDelete: FaceProfile?
    @State private var isShowingDeleteAlert = false
    @State private var hasPassword = false
    @State private var isAccessibilityGranted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Header Banner
                headerSection

                Divider()

                // Face Profiles Manager
                profilesSection

                Divider()

                // Unlock Mode & Authentication Configuration
                unlockModeSection

                Divider()

                // Foreground Face ID Verification Harness
                FaceTestSection(profiles: profiles)

                Divider()

                // Preferences
                preferencesSection
            }
            .padding(26)
            .frame(maxWidth: 580)
        }
        .frame(minWidth: 540, idealWidth: 560, maxWidth: 650, minHeight: 620, idealHeight: 700)
        .onAppear {
            refreshData()
        }
        .sheet(isPresented: $isShowingEnrollmentSheet, onDismiss: refreshData) {
            EnrollmentModalView()
        }
        .sheet(isPresented: $isShowingPasswordSheet, onDismiss: refreshData) {
            PasswordSetupModalView()
        }
        .alert("Delete Face Profile", isPresented: $isShowingDeleteAlert, presenting: profileToDelete) { profile in
            Button("Delete", role: .destructive) {
                _ = KeychainStore.deleteProfile(id: profile.id)
                refreshData()
            }
            Button("Cancel", role: .cancel) {}
        } message: { profile in
            Text("Are you sure you want to delete '\(profile.name)'? Lookt will no longer match against this appearance.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 18) {
            FaceIDScanView(state: isLooktEnabled && !profiles.isEmpty ? .success : .idle, size: 70)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Lookt")
                        .font(.title2).bold()

                    Text(isLooktEnabled ? (profiles.isEmpty ? "No Profiles" : "Active") : "Paused")
                        .font(.caption2).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            isLooktEnabled
                                ? (profiles.isEmpty ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                                : Color.secondary.opacity(0.2)
                        )
                        .foregroundColor(
                            isLooktEnabled
                                ? (profiles.isEmpty ? .orange : .green)
                                : .secondary
                        )
                        .clipShape(Capsule())
                }

                Text("Face ID unlock and authentication for your Mac.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isLooktEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Registered Faces (\(profiles.count))", systemImage: "person.crop.rectangle.stack")
                    .font(.headline)

                Spacer()

                Button {
                    isShowingEnrollmentSheet = true
                } label: {
                    Label("Add Face Style", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            let hasLegacyProfiles = profiles.contains { ($0.embeddings.first?.count ?? 0) != 522 }
            if hasLegacyProfiles {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Security Upgrade Available")
                            .font(.callout).bold()
                        Text("Your registered profile was saved with the legacy model. Please delete it below and re-enroll to activate Apple Neural Face ID and anti-photo protection.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
            }

            if profiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "faceid")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.7))

                    Text("No face profiles registered")
                        .font(.callout).bold()

                    Text("Add your primary face to get started. You can also add styles like 'With Glasses' or 'Low Light' for better accuracy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)

                    Button("Enroll Primary Face") {
                        isShowingEnrollmentSheet = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
            } else {
                VStack(spacing: 8) {
                    ForEach(profiles) { profile in
                        HStack(spacing: 14) {
                            Image(systemName: profile.style.iconName)
                                .font(.title3)
                                .foregroundColor(.accentColor)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.accentColor.opacity(0.12)))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name)
                                    .font(.body).fontWeight(.medium)

                                HStack(spacing: 6) {
                                    Text(profile.style.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.secondary.opacity(0.15)))

                                    Text("Added \(profile.dateEnrolled.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    if (profile.embeddings.first?.count ?? 0) == 522 {
                                        Text("Neural")
                                            .font(.caption2).bold()
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.green.opacity(0.18)))
                                            .foregroundColor(.green)
                                    } else {
                                        Text("Legacy")
                                            .font(.caption2).bold()
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                                            .foregroundColor(.orange)
                                    }
                                }
                            }

                            Spacer()

                            Button {
                                profileToDelete = profile
                                isShowingDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Delete this face profile")
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
                    }
                }
            }
        }
    }

    private var unlockModeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Authentication & Unlock Mode", systemImage: "lock.shield")
                .font(.headline)

            Picker("Unlock Mode", selection: $unlockModeRaw) {
                ForEach(UnlockMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

            let currentMode = UnlockMode(rawValue: unlockModeRaw) ?? .autoUnlock
            Text(currentMode.description)
                .font(.caption)
                .foregroundColor(.secondary)

            if currentMode == .autoUnlock {
                VStack(alignment: .leading, spacing: 10) {
                    // Password Status Row
                    HStack {
                        Image(systemName: hasPassword ? "key.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(hasPassword ? .green : .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hasPassword ? "Mac Login Password Configured" : "Login Password Required")
                                .font(.callout).fontWeight(.medium)
                            Text(hasPassword ? "Encrypted locally in Keychain for automated unlock." : "Set your password so Lookt can unlock your Mac.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(hasPassword ? "Change" : "Set Password") {
                            isShowingPasswordSheet = true
                        }
                        .buttonStyle(.bordered)

                        if hasPassword {
                            Button("Remove") {
                                KeychainStore.deleteLoginPassword()
                                refreshData()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))

                    // Accessibility Permission Row
                    HStack {
                        Image(systemName: isAccessibilityGranted ? "checkmark.circle.fill" : "lock.open.trianglebadge.exclamationmark")
                            .foregroundColor(isAccessibilityGranted ? .green : .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isAccessibilityGranted ? "Accessibility Permission Granted" : "Accessibility Permission Required")
                                .font(.callout).fontWeight(.medium)
                            Text(isAccessibilityGranted ? "Lookt can simulate keyboard unlock signals." : "Required for typing your password at the lock screen.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !isAccessibilityGranted {
                            Button("Grant Access") {
                                MacUnlocker.shared.requestAccessibilityPermission()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    refreshData()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
                }
            }
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Preferences", systemImage: "gearshape")
                .font(.headline)

            Toggle("Launch Lookt automatically at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            .toggleStyle(.switch)

            Toggle("Boost screen brightness automatically in low light", isOn: $boostBrightness)
                .toggleStyle(.switch)
        }
    }

    private func refreshData() {
        profiles = KeychainStore.loadProfiles()
        hasPassword = KeychainStore.hasLoginPassword()
        isAccessibilityGranted = MacUnlocker.shared.isAccessibilityGranted
    }
}

// MARK: - Face ID Live Test Section

private struct FaceTestSection: View {
    let profiles: [FaceProfile]
    @StateObject private var test = FaceTestController()
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Test Face ID", systemImage: "sparkle.magnifyingglass")
                    .font(.headline)

                Spacer()

                Button(isRunning ? "Stop Test" : (test.scanState == .idle ? "Test Face ID" : "Try Again")) {
                    if isRunning {
                        test.stop()
                        isRunning = false
                    } else {
                        test.reset()
                        test.start()
                        isRunning = true
                    }
                }
                .buttonStyle(.bordered)
                .disabled(profiles.isEmpty)
            }

            if isRunning || test.scanState != .idle {
                HStack(alignment: .center, spacing: 20) {
                    CameraPreviewView(session: test.previewSession)
                        .frame(width: 180, height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        .opacity(isRunning ? 1.0 : 0.4)

                    VStack(alignment: .leading, spacing: 8) {
                        FaceIDScanView(state: test.scanState, size: 80)

                        if !test.resultMessage.isEmpty {
                            Text(test.resultMessage)
                                .font(.callout).bold()
                                .foregroundColor(test.scanState == .success ? .green : (test.scanState == .failed ? .red : .primary))
                        }

                        if isRunning {
                            Text(String(format: "Score: %.2f (Blink + move gently)", test.lastScore))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
            }
        }
        .onChange(of: test.scanState) { _, newState in
            if newState == .success || newState == .failed {
                isRunning = false
            }
        }
    }
}

// MARK: - Enrollment Modal Sheet

private struct EnrollmentModalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = FaceEnrollmentController()
    @State private var profileName: String = ""
    @State private var selectedStyle: ProfileStyle = .defaultFace
    @State private var hasStarted = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Face Profile")
                .font(.title2).bold()

            if !hasStarted {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profile Label")
                            .font(.caption).bold().foregroundColor(.secondary)
                        TextField("e.g. Sanjay (Default), Reading Glasses", text: $profileName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Appearance Style")
                            .font(.caption).bold().foregroundColor(.secondary)

                        Picker("Style", selection: $selectedStyle) {
                            ForEach(ProfileStyle.allCases) { style in
                                Label(style.rawValue, systemImage: style.iconName).tag(style)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(selectedStyle.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Begin Capture") {
                        let finalName = profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? selectedStyle.rawValue
                            : profileName
                        hasStarted = true
                        controller.startEnrollment(name: finalName, style: selectedStyle)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    if !controller.isComplete {
                        CameraPreviewView(session: controller.previewSession)
                            .frame(width: 260, height: 195)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 2))
                    } else {
                        FaceIDScanView(state: .success, size: 90)
                    }

                    Text(controller.statusMessage)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    HStack(spacing: 14) {
                        if controller.isComplete {
                            Button("Done") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Cancel") {
                                controller.reset()
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }
        }
        .padding(26)
        .frame(width: 440)
    }
}

// MARK: - Password Setup Modal Sheet (With Show/Hide Password Eye Toggle)

private struct PasswordSetupModalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 18) {
            Text("Set Mac Login Password")
                .font(.title3).bold()

            Text("Your password is encrypted and stored in your device's local macOS Keychain. Lookt uses it only to unlock your Mac upon a verified Face ID match.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if showPassword {
                        TextField("Mac Login Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Mac Login Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showPassword ? "Hide password" : "Show password")
                }

                if showPassword {
                    TextField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(12)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save Password") {
                    guard !password.isEmpty else {
                        errorMessage = "Password cannot be empty."
                        return
                    }
                    guard password == confirmPassword else {
                        errorMessage = "Passwords do not match."
                        return
                    }

                    if KeychainStore.saveLoginPassword(password) {
                        dismiss()
                    } else {
                        errorMessage = "Failed to save password to Keychain."
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

import SwiftUI

struct EnrollmentView: View {
    @StateObject private var controller = FaceEnrollmentController()
    @StateObject private var loginItem = LoginItemManager()
    @State private var hasStarted = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Lookt")
                .font(.title2).bold()

            if hasStarted && !controller.isComplete {
                CameraPreviewView(session: controller.previewSession)
                    .frame(width: 280, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 2))
            } else {
                FaceIDScanView(state: controller.isComplete ? .success : .idle)
                    .frame(height: 210)
            }

            Text(controller.statusMessage)
                .multilineTextAlignment(.center)
                .frame(width: 320)

            if !controller.isComplete {
                Button("Start Enrollment") {
                    hasStarted = true
                    controller.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasStarted)
            } else {
                Text("Lookt will now watch for your face whenever the screen is locked.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 320)
                    .multilineTextAlignment(.center)

                Button("Re-enroll") {
                    controller.reset()
                    hasStarted = false
                }
                .buttonStyle(.bordered)
            }

            Divider().padding(.top, 4)

            Toggle("Launch Lookt at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            .toggleStyle(.switch)

            if controller.isComplete {
                TestScanSection()
            }
        }
        .padding(30)
        .frame(width: 400, height: controller.isComplete ? 660 : 460)
    }
}

/// Lets you verify the whole pipeline — camera, liveness, matching,
/// animation — safely in the foreground. Never touches the real lock
/// screen or types anything anywhere; it's a pass/fail readout only.
private struct TestScanSection: View {
    @StateObject private var test = FaceTestController()
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Test your enrollment")
                .font(.headline)

            if isRunning || test.scanState != .idle {
                CameraPreviewView(session: test.previewSession)
                    .frame(width: 200, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .opacity(isRunning ? 1 : 0.3)

                FaceIDScanView(state: test.scanState)
                    .frame(height: 90)

                if !test.resultMessage.isEmpty {
                    Text(test.resultMessage)
                        .font(.callout)
                        .foregroundColor(test.scanState == .success ? .green : (test.scanState == .failed ? .red : .secondary))
                        .multilineTextAlignment(.center)
                        .frame(width: 260)
                }

                if isRunning {
                    Text(String(format: "Live match score: %.2f", test.lastScore))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button(isRunning ? "Stop Test" : (test.scanState == .idle ? "Test My Face" : "Try Again")) {
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
            .onChange(of: test.scanState) { newState in
                // Auto-flip the button back to "Try Again" once scanning
                // ends on its own (success or timeout), without needing
                // the user to click Stop first.
                if newState == .success || newState == .failed {
                    isRunning = false
                }
            }
        }
    }
}

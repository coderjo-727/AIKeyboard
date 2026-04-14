import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var state = CorrectionExperienceState.loading
    @State private var didStartLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    runtimeCard
                    setupCard
                    diagnosticsCard
                    privacyCard
                    testingCard
                    liveCorrectionCard
                }
                .padding(22)
            }
            .navigationTitle("AI Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.background.ignoresSafeArea())
        }
        .task {
            guard !didStartLoading else { return }
            didStartLoading = true
            await loadCorrectionExperience()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A calmer keyboard for corrections you approve.")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            Text("AI Keyboard reviews the active sentence, shows the change, and waits. No silent rewrites, no hidden history, and no pressure to accept a suggestion.")
                .font(.title3.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 8) {
                badge("Review-first")
                badge("Private by default")
                badge("Local fallback")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroFill, in: RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var runtimeCard: some View {
        statusCard(
            eyebrow: "CORRECTION ENGINE",
            title: state.runtimeHeadline,
            body: state.runtimeBody
        ) {
            HStack(spacing: 10) {
                statusDot(color: state.source == .relay ? AppTheme.success : AppTheme.warning)
                Text(state.runtimeBadge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.72), in: Capsule())
        }
    }

    private var setupCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Set Up The Keyboard")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                VStack(alignment: .leading, spacing: 10) {
                    stepRow(number: "1", text: "Install this app on your iPhone or iPad from Xcode.")
                    stepRow(number: "2", text: "Open Settings > General > Keyboard > Keyboards > Add New Keyboard.")
                    stepRow(number: "3", text: "Choose AIKeyboard, then enable Full Access if you want relay-backed corrections.")
                    stepRow(number: "4", text: "Switch keyboards inside Notes or Messages and type naturally.")
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Text("Open App Settings")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
            }
        }
    }

    private var diagnosticsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Status & Troubleshooting")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                diagnosticRow(
                    label: "Relay endpoint",
                    value: state.relayEndpointDisplay,
                    tone: state.hasRelayConfiguration ? .good : .warning
                )
                diagnosticRow(
                    label: "Keyboard network access",
                    value: "Enable Full Access in iOS Keyboard settings to allow relay-backed corrections.",
                    tone: .neutral
                )
                diagnosticRow(
                    label: "Fallback behavior",
                    value: "If the relay is missing or unreachable, suggestions stay local and conservative.",
                    tone: .good
                )
                diagnosticRow(
                    label: "Secrets",
                    value: "OpenAI API keys belong on the relay server only. The app stores no raw text profile.",
                    tone: .good
                )
            }
        }
    }

    private var privacyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy Model")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                featureRow("Suggestions stay sentence-scoped.")
                featureRow("Accept and reject memory resets with the keyboard session.")
                featureRow("If relay is unavailable, the built-in local provider keeps working.")
                featureRow("The OpenAI key belongs on the relay server, never in the app.")
            }
        }
    }

    private var testingCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Personal Test Checklist")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                checklistRow("Type normally and confirm letters do not auto-space.")
                checklistRow("Double-tap space after a word and confirm it becomes period + space.")
                checklistRow("Try `i has a apple` and confirm preview appears only when the suggestion is conservative.")
                checklistRow("Use Not Now, Hide This Session, and Apply from the review panel.")
                checklistRow("Disable the relay or network and confirm the keyboard keeps working locally.")
            }
        }
    }

    private var liveCorrectionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Live Correction Snapshot")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                labeledText("Input", state.analysis.activeSentence.text)
                labeledText("Suggestion", state.analysis.suggestion?.corrected ?? "No correction surfaced")

                if !state.analysis.diff.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Change List")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.secondaryText)

                        ForEach(Array(state.analysis.diff.enumerated()), id: \.offset) { _, segment in
                            if segment.kind != .unchanged {
                                HStack(alignment: .top, spacing: 10) {
                                    Text(segment.kind.rawValue.capitalized)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(AppTheme.accentSoft, in: Capsule())

                                    Text("\(display(segment.original)) -> \(display(segment.replacement))")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(AppTheme.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(10)
                                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }
            }
        }
    }

    private func statusCard<Accessory: View>(
        eyebrow: String,
        title: String,
        body: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(eyebrow)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    accessory()
                }

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(body)
                    .foregroundStyle(AppTheme.secondaryText)

                if !state.setupSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(state.setupSteps.enumerated()), id: \.offset) { index, step in
                            stepRow(number: "\(index + 1)", text: step)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.accentSoft, in: Capsule())
            .foregroundStyle(AppTheme.accent)
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .frame(width: 24, height: 24)
                .background(AppTheme.accentSoft, in: Circle())
                .foregroundStyle(AppTheme.accent)

            Text(text)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 6, height: 6)
            Text(text)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func checklistRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.accent)
            Text(text)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func diagnosticRow(label: String, value: String, tone: DiagnosticTone) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tone.color)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(value)
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
    }

    private func labeledText(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.body.monospaced())
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func statusDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private func display(_ value: String) -> String {
        value.isEmpty ? "empty" : value
    }

    @MainActor
    private func loadCorrectionExperience() async {
        let configuration = CorrectionRuntimeConfigurationLoader.load()
        let result = await CorrectionRuntime.analyze(
            context: TextContext(
                beforeInput: "hey there. i has a apple",
                afterInput: ""
            ),
            configuration: configuration,
            prefersRemote: true
        )
        state = CorrectionExperienceState(
            analysis: result.analysis,
            source: result.source,
            relayConfiguration: configuration?.relay
        )
    }
}

private struct CorrectionExperienceState {
    let analysis: CorrectionAnalysis
    let source: CorrectionRuntimeResult.Source
    let relayConfiguration: CorrectionRuntimeConfiguration.Relay?

    var hasRelayConfiguration: Bool {
        relayConfiguration != nil
    }

    static let loading = CorrectionExperienceState(
        analysis: CorrectionPipeline.analyzeLocally(
            context: TextContext(
                beforeInput: "hey there. i has a apple",
                afterInput: ""
            )
        ),
        source: .localOnly,
        relayConfiguration: nil
    )

    var runtimeHeadline: String {
        switch source {
        case .relay:
            return "Relay-backed corrections are active."
        case .localFallback:
            return hasRelayConfiguration
                ? "Relay configured, local fallback active."
                : "Local correction engine active."
        case .localOnly:
            return "Local correction engine active."
        }
    }

    var runtimeBadge: String {
        switch source {
        case .relay:
            return "Relay"
        case .localFallback:
            return "Fallback"
        case .localOnly:
            return "Local"
        }
    }

    var runtimeBody: String {
        switch source {
        case .relay:
            return "The app found a relay configuration and successfully used it for this correction pass. The same review and safety gates still apply before anything changes."
        case .localFallback:
            return hasRelayConfiguration
                ? "A relay endpoint is configured, but the last correction pass fell back cleanly to the built-in conservative engine."
                : "No relay is configured yet, so the app is using the built-in conservative provider."
        case .localOnly:
            return "No relay is configured yet, so the app is using the built-in conservative provider."
        }
    }

    var setupSteps: [String] {
        guard !hasRelayConfiguration else {
            return []
        }

        return [
            "Add AIKeyboardRelayEndpoint to the app Info.plist or set AIKEYBOARD_RELAY_ENDPOINT in the scheme environment.",
            "If your relay expects auth, also provide AIKeyboardRelayToken or AIKEYBOARD_RELAY_TOKEN."
        ]
    }

    var relayEndpointDisplay: String {
        guard let endpoint = relayConfiguration?.endpoint else {
            return "Not configured. Local correction is active."
        }

        let host = endpoint.host ?? "unknown host"
        let scheme = endpoint.scheme?.uppercased() ?? "unknown"
        return "\(scheme) relay configured at \(host)"
    }
}

private enum DiagnosticTone {
    case good
    case warning
    case neutral

    var color: Color {
        switch self {
        case .good:
            return AppTheme.success
        case .warning:
            return AppTheme.warning
        case .neutral:
            return AppTheme.accent
        }
    }
}

private enum AppTheme {
    static let ink = Color(red: 0.08, green: 0.14, blue: 0.11)
    static let secondaryText = Color(red: 0.36, green: 0.42, blue: 0.38)
    static let accent = Color(red: 0.09, green: 0.39, blue: 0.30)
    static let accentSoft = Color(red: 0.84, green: 0.92, blue: 0.88)
    static let success = Color(red: 0.10, green: 0.55, blue: 0.35)
    static let warning = Color(red: 0.78, green: 0.52, blue: 0.18)
    static let border = Color(red: 0.78, green: 0.84, blue: 0.78).opacity(0.75)
    static let cardFill = Color.white.opacity(0.86)
    static let heroFill = LinearGradient(
        colors: [
            Color.white.opacity(0.98),
            Color(red: 0.88, green: 0.95, blue: 0.89),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let background = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.97, blue: 0.94),
            Color(red: 0.89, green: 0.94, blue: 0.89),
            Color(red: 0.84, green: 0.89, blue: 0.84),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

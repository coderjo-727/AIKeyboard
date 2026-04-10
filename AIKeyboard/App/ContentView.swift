import SwiftUI

struct ContentView: View {
    @State private var state = CorrectionExperienceState.loading
    @State private var didStartLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroCard
                    runtimeCard
                    enablementCard
                    sentencePreviewCard
                    card(
                        title: "Why It Feels Different",
                        body: "The keyboard stays intentionally quiet. It only surfaces conservative suggestions, keeps review inside the keyboard, and treats rejection as a signal instead of pushing harder."
                    )
                    card(
                        title: "Current Alpha Boundary",
                        body: "This build now covers sentence extraction, visible diffs, safe apply behavior, session-only memory, and relay-ready runtime selection. It is an early working alpha, not a throwaway mockup."
                    )
                }
                .padding(24)
            }
            .navigationTitle("AI Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.94),
                        Color(red: 0.90, green: 0.94, blue: 0.90),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
        .task {
            guard !didStartLoading else { return }
            didStartLoading = true
            await loadCorrectionExperience()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Private writing help that behaves like a product.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))

            Text("Sentence-scoped spelling, grammar, and punctuation correction with visible diffs, explicit review, and a runtime that can step up to a relay-backed provider when configured.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                badge("Preview-first")
                badge("Session-only memory")
                badge("No silent rewrites")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.95),
                    Color(red: 0.92, green: 0.97, blue: 0.93),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28)
        )
    }

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Correction Runtime")
                .font(.headline)

            Text(state.runtimeHeadline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))

            Text(state.runtimeBody)
                .foregroundStyle(.secondary)

            if !state.setupSteps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(state.setupSteps.enumerated()), id: \.offset) { index, step in
                        stepRow(number: "\(index + 1)", text: step)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))
    }

    private var enablementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Enable On Device")
                .font(.headline)

            Text("Install the app, then go to Settings > General > Keyboard > Keyboards > Add New Keyboard and choose AIKeyboard.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                stepRow(number: "1", text: "Run the AIKeyboard app target on a physical iPhone or iPad.")
                stepRow(number: "2", text: "Open Keyboard settings and add AIKeyboard.")
                stepRow(number: "3", text: "If you want relay-backed corrections inside the keyboard, enable Full Access for AIKeyboard.")
                stepRow(number: "4", text: "Switch to AIKeyboard in Notes or Messages and test a sentence like i has a apple.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))
    }

    private var sentencePreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Live Correction Snapshot")
                .font(.headline)

            Text("Active sentence")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(state.analysis.activeSentence.text)
                .font(.body.monospaced())

            Text("Suggested correction")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(state.analysis.suggestion?.corrected ?? "No correction surfaced")
                .font(.body.monospaced())

            if !state.analysis.diff.isEmpty {
                Text("Diff summary")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(state.analysis.diff.enumerated()), id: \.offset) { _, segment in
                    if segment.kind != .unchanged {
                        HStack(alignment: .top, spacing: 10) {
                            Text(segment.kind.rawValue.capitalized)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.15), in: Capsule())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("From: \(segment.original.isEmpty ? "∅" : segment.original)")
                                Text("To: \(segment.replacement.isEmpty ? "∅" : segment.replacement)")
                            }
                            .font(.caption.monospaced())
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
    }

    private func card(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(body)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.84, green: 0.92, blue: 0.88), in: Capsule())
            .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.30))
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .frame(width: 24, height: 24)
                .background(Color(red: 0.84, green: 0.92, blue: 0.88), in: Circle())
                .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.30))

            Text(text)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            hasRelayConfiguration: configuration?.relay != nil
        )
    }
}

private struct CorrectionExperienceState {
    let analysis: CorrectionAnalysis
    let source: CorrectionRuntimeResult.Source
    let hasRelayConfiguration: Bool

    static let loading = CorrectionExperienceState(
        analysis: CorrectionPipeline.analyzeLocally(
            context: TextContext(
                beforeInput: "hey there. i has a apple",
                afterInput: ""
            )
        ),
        source: .localOnly,
        hasRelayConfiguration: false
    )

    var runtimeHeadline: String {
        switch source {
        case .relay:
            return "Relay-backed corrections are active."
        case .localFallback:
            return hasRelayConfiguration
                ? "Relay is configured, but local fallback is currently carrying the correction flow."
                : "Running on the local fallback engine."
        case .localOnly:
            return "Running on the local on-device correction path."
        }
    }

    var runtimeBody: String {
        switch source {
        case .relay:
            return "The app found a relay configuration and successfully used it for the current correction pass. The same review and safety gates still apply before anything changes."
        case .localFallback:
            return hasRelayConfiguration
                ? "A relay endpoint is configured, but the last correction pass fell back cleanly to the built-in conservative engine. That keeps the product usable even when the network path is unavailable."
                : "No relay is configured yet, so the app is using the built-in conservative provider. This is still fully usable for alpha testing."
        case .localOnly:
            return "The app is currently set up to stay local. This is the lowest-risk path while the relay remains optional."
        }
    }

    var setupSteps: [String] {
        guard !hasRelayConfiguration else {
            return []
        }

        return [
            "Add AIKeyboardRelayEndpoint to the app Info.plist or set AIKEYBOARD_RELAY_ENDPOINT in the scheme environment.",
            "If your relay expects auth, also provide AIKeyboardRelayToken or AIKEYBOARD_RELAY_TOKEN.",
            "For keyboard-side relay use, enable Full Access after installing the app."
        ]
    }
}

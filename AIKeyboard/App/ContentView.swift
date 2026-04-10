import SwiftUI

struct ContentView: View {
    private let analysis = SimpleCorrectionEngine.analyze(
        context: TextContext(
            beforeInput: "hey there. i has a apple",
            afterInput: ""
        )
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("AI Keyboard")
                        .font(.largeTitle.weight(.bold))

                    Text("Privacy-first AI correction that previews changes before they are applied.")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    card(
                        title: "MVP Focus",
                        body: "Sentence-scoped spelling, grammar, and punctuation corrections with visual diffs and explicit apply or cancel actions."
                    )

                    sentencePreviewCard

                    card(
                        title: "Privacy Model",
                        body: "No raw text storage, no cross-session memory, and no surprise edits. Session-only adaptation stays in memory."
                    )

                    card(
                        title: "Next Build Step",
                        body: "Wire the shared AIKeyboardCore package into the app and extension, then replace placeholder UI with real keyboard interactions."
                    )
                }
                .padding(24)
            }
            .navigationTitle("Local Scaffold")
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.98, blue: 0.96),
                        Color(red: 0.88, green: 0.93, blue: 0.90),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }

    private var sentencePreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Shared Core Demo")
                .font(.headline)

            Text("Active sentence")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(analysis.activeSentence.text)
                .font(.body.monospaced())

            Text("Suggested correction")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(analysis.suggestion?.corrected ?? "No correction surfaced")
                .font(.body.monospaced())

            if !analysis.diff.isEmpty {
                Text("Diff summary")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(analysis.diff.enumerated()), id: \.offset) { _, segment in
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
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
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
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
    }
}

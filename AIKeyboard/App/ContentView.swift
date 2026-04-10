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
                VStack(alignment: .leading, spacing: 22) {
                    heroCard
                    enablementCard
                    sentencePreviewCard
                    card(
                        title: "Why It Feels Different",
                        body: "The keyboard stays intentionally quiet. It only surfaces conservative suggestions, keeps review inside the keyboard, and treats rejection as a signal instead of pushing harder."
                    )
                    card(
                        title: "Current MVP Boundary",
                        body: "This build focuses on sentence extraction, visible diffs, safe apply behavior, and session-only memory. It is still a local-first prototype, not a production keyboard yet."
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
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Private writing help that waits for permission.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))

            Text("Sentence-scoped spelling, grammar, and punctuation correction with visible diffs and explicit review before anything changes.")
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

    private var enablementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Enable On Device")
                .font(.headline)

            Text("Install the app, then go to Settings > General > Keyboard > Keyboards > Add New Keyboard and choose AIKeyboard.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                stepRow(number: "1", text: "Run the AIKeyboard app target on a physical iPhone or iPad.")
                stepRow(number: "2", text: "Open Keyboard settings and add AIKeyboard.")
                stepRow(number: "3", text: "Switch to AIKeyboard in Notes or Messages and test a sentence like i has a apple.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))
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
}

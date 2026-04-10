final class KeyboardSessionMemory {
    private var rejectedFingerprints: Set<String> = []
    private var acceptedFingerprints: Set<String> = []
    private var temporarilyDismissedFingerprint: String?

    func filteredAnalysis(from analysis: CorrectionAnalysis?) -> CorrectionAnalysis? {
        syncTemporaryDismissal(with: analysis?.suggestion)

        guard
            let analysis,
            let suggestion = analysis.suggestion
        else {
            return analysis
        }

        guard shouldSuppress(suggestion) else {
            return analysis
        }

        return CorrectionAnalysis(
            activeSentence: analysis.activeSentence,
            suggestion: nil,
            diff: []
        )
    }

    func recordAcceptance(for analysis: CorrectionAnalysis?) {
        guard let fingerprint = analysis?.suggestion?.fingerprint else { return }
        acceptedFingerprints.insert(fingerprint)
        rejectedFingerprints.remove(fingerprint)
        if temporarilyDismissedFingerprint == fingerprint {
            temporarilyDismissedFingerprint = nil
        }
    }

    func recordDismissal(for analysis: CorrectionAnalysis?) {
        guard let fingerprint = analysis?.suggestion?.fingerprint else { return }
        guard !acceptedFingerprints.contains(fingerprint) else { return }
        temporarilyDismissedFingerprint = fingerprint
    }

    func recordRejection(for analysis: CorrectionAnalysis?) {
        guard let fingerprint = analysis?.suggestion?.fingerprint else { return }
        guard !acceptedFingerprints.contains(fingerprint) else { return }
        temporarilyDismissedFingerprint = nil
        rejectedFingerprints.insert(fingerprint)
    }

    func reset() {
        rejectedFingerprints.removeAll()
        acceptedFingerprints.removeAll()
        temporarilyDismissedFingerprint = nil
    }

    private func shouldSuppress(_ suggestion: CorrectionSuggestion) -> Bool {
        let fingerprint = suggestion.fingerprint
        guard !acceptedFingerprints.contains(fingerprint) else {
            return false
        }

        return rejectedFingerprints.contains(fingerprint)
            || temporarilyDismissedFingerprint == fingerprint
    }

    private func syncTemporaryDismissal(with suggestion: CorrectionSuggestion?) {
        guard let dismissedFingerprint = temporarilyDismissedFingerprint else {
            return
        }

        guard let suggestion else {
            temporarilyDismissedFingerprint = nil
            return
        }

        guard suggestion.fingerprint == dismissedFingerprint else {
            temporarilyDismissedFingerprint = nil
            return
        }
    }
}

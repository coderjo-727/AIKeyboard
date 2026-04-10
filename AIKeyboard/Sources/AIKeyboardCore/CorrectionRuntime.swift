import Foundation

public struct CorrectionRuntimeConfiguration: Sendable, Equatable {
    public struct Relay: Sendable, Equatable {
        public let endpoint: URL
        public let apiKey: String?

        public init(endpoint: URL, apiKey: String? = nil) {
            self.endpoint = endpoint
            self.apiKey = apiKey
        }
    }

    public let relay: Relay?

    public init(relay: Relay? = nil) {
        self.relay = relay
    }
}

public struct CorrectionRuntimeResult: Sendable, Equatable {
    public enum Source: String, Sendable {
        case relay
        case localFallback
        case localOnly
    }

    public let analysis: CorrectionAnalysis
    public let source: Source

    public init(analysis: CorrectionAnalysis, source: Source) {
        self.analysis = analysis
        self.source = source
    }
}

public enum CorrectionRuntime {
    public static func analyze(
        context: TextContext,
        configuration: CorrectionRuntimeConfiguration?,
        prefersRemote: Bool = true
    ) async -> CorrectionRuntimeResult {
        if prefersRemote, let relay = configuration?.relay {
            return await analyze(
                context: context,
                remoteProvider: RelayCorrectionProvider(
                    configuration: .init(
                        endpoint: relay.endpoint,
                        apiKey: relay.apiKey
                    )
                ),
                fallbackProvider: RuleBasedCorrectionProvider()
            )
        }

        return CorrectionRuntimeResult(
            analysis: CorrectionPipeline.analyzeLocally(context: context),
            source: .localOnly
        )
    }

    static func analyze<Remote: CorrectionProvider, Fallback: CorrectionProvider>(
        context: TextContext,
        remoteProvider: Remote,
        fallbackProvider: Fallback
    ) async -> CorrectionRuntimeResult {
        let (activeSentence, request) = CorrectionPipeline.makeRequest(for: context)

        do {
            if let remoteSuggestion = try await remoteProvider.suggestCorrection(for: request) {
                return CorrectionRuntimeResult(
                    analysis: CorrectionPipeline.buildAnalysis(
                        context: context,
                        activeSentence: activeSentence,
                        rawSuggestion: remoteSuggestion
                    ),
                    source: .relay
                )
            }
        } catch {
            return await analyzeFallback(
                context: context,
                activeSentence: activeSentence,
                request: request,
                fallbackProvider: fallbackProvider
            )
        }

        return await analyzeFallback(
            context: context,
            activeSentence: activeSentence,
            request: request,
            fallbackProvider: fallbackProvider
        )
    }

    private static func analyzeFallback<Provider: CorrectionProvider>(
        context: TextContext,
        activeSentence: ActiveSentence,
        request: CorrectionProviderRequest,
        fallbackProvider: Provider
    ) async -> CorrectionRuntimeResult {
        let rawSuggestion = try? await fallbackProvider.suggestCorrection(for: request)
        return CorrectionRuntimeResult(
            analysis: CorrectionPipeline.buildAnalysis(
                context: context,
                activeSentence: activeSentence,
                rawSuggestion: rawSuggestion
            ),
            source: .localFallback
        )
    }
}

public enum CorrectionRuntimeConfigurationLoader {
    public static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> CorrectionRuntimeConfiguration? {
        let endpointString = value(
            for: "AIKEYBOARD_RELAY_ENDPOINT",
            bundleKey: "AIKeyboardRelayEndpoint",
            bundle: bundle,
            environment: environment
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let endpointString, !endpointString.isEmpty, let endpoint = URL(string: endpointString) else {
            return nil
        }

        let apiKey = value(
            for: "AIKEYBOARD_RELAY_TOKEN",
            bundleKey: "AIKeyboardRelayToken",
            bundle: bundle,
            environment: environment
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        return CorrectionRuntimeConfiguration(
            relay: .init(
                endpoint: endpoint,
                apiKey: apiKey?.isEmpty == true ? nil : apiKey
            )
        )
    }

    private static func value(
        for environmentKey: String,
        bundleKey: String,
        bundle: Bundle,
        environment: [String: String]
    ) -> String? {
        if let value = environment[environmentKey], !value.isEmpty {
            return value
        }

        return bundle.object(forInfoDictionaryKey: bundleKey) as? String
    }
}

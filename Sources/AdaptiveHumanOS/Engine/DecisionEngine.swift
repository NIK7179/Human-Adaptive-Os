import Foundation

public protocol AdaptiveDecisionEngine: Sendable {
    func evaluate(
        snapshot: ContextSnapshot,
        preferences: AdaptivePreferences,
        history: AdaptationHistory
    ) async -> AdaptationDecision
}

/// The transparent, deterministic decision engine (Section B).
///
/// Determinism: identical snapshot/preferences/history (with fixed clock and
/// ID providers) produce identical semantic output. Votes are sorted before
/// summation so signal-processing order never affects a score; every
/// returned collection uses documented stable ordering; the evaluation
/// timestamp is captured exactly once per evaluation.
public struct TransparentAdaptiveDecisionEngine: AdaptiveDecisionEngine {
    public let configuration: AdaptiveEngineConfiguration
    public let scoring: AdaptiveScoringConfiguration
    public let clock: any AdaptiveClock
    public let idGenerator: any AdaptiveIDGenerating
    public let themeComposer: any AdaptiveThemeComposing

    private let normalizer = LogisticScoreNormalizer(temperature: 1.0)

    public init(
        configuration: AdaptiveEngineConfiguration = .production,
        scoring: AdaptiveScoringConfiguration = .production,
        clock: any AdaptiveClock,
        idGenerator: any AdaptiveIDGenerating,
        themeComposer: any AdaptiveThemeComposing = DefaultThemeComposer()
    ) {
        self.configuration = configuration
        self.scoring = scoring
        self.clock = clock
        self.idGenerator = idGenerator
        self.themeComposer = themeComposer
    }

    public func evaluate(
        snapshot: ContextSnapshot,
        preferences: AdaptivePreferences,
        history: AdaptationHistory
    ) async -> AdaptationDecision {
        // Production timestamp policy (B.23A): captured ONCE, reused everywhere.
        let evaluationTime = clock.now

        // Stages 1–3: validate availability, normalize, generate signals.
        let generator = ContextSignalGenerator(configuration: scoring, idGenerator: idGenerator)
        let allSignals = await generator.signals(from: snapshot)
        let validSignals = allSignals.filter { $0.isValid(at: evaluationTime) }
        let ignoredSignals: [IgnoredSignal] = allSignals
            .filter { !$0.isValid(at: evaluationTime) }
            .map { IgnoredSignal(kind: $0.kind, reason: "This observation had expired and was ignored.") }
            .sorted { $0.kind.rawValue < $1.kind.rawValue }

        // Stages 4–9: votes → per-mode sums.
        let isNight = snapshot.solarPhase == .night || snapshot.solarPhase == .polarNight
        var votes: [ModeVote] = []
        // Sorted before vote generation AND before summation so that input
        // order can never affect floating-point accumulation.
        let orderedSignals = validSignals.sorted {
            ($0.kind.rawValue, $0.id.uuidString) < ($1.kind.rawValue, $1.id.uuidString)
        }
        for signal in orderedSignals {
            for definition in scoring.definitions(for: signal.kind) {
                let preferenceModifier = preferences.preferenceModifier(
                    for: definition.mode,
                    minimumSamples: configuration.personalizationMinimumSamples
                )
                let contextualModifier = isNight ? definition.nightContextModifier : 1.0
                votes.append(
                    ModeVote(
                        id: await idGenerator.makeID(),
                        signalID: signal.id,
                        signalKind: signal.kind,
                        mode: definition.mode,
                        baseWeight: definition.baseWeight,
                        signalStrength: signal.normalizedValue,
                        reliability: signal.reliability,
                        preferenceModifier: preferenceModifier,
                        contextualModifier: contextualModifier,
                        explanation: signal.explanation
                    )
                )
            }
        }

        var scores: [ModeScore] = []
        for mode in AdaptiveScoringConfiguration.automaticCandidates {
            let modeVotes = votes
                .filter { $0.mode == mode }
                .sorted { stableVoteOrder($0, $1) }
            let rawScore = modeVotes.reduce(0.0) { $0 + $1.finalContribution }
            var exclusionReasons: [String] = []
            var isEligible = true
            if preferences.disabledModes.contains(mode) {
                exclusionReasons.append("You asked not to be offered \(mode.displayName).")
                isEligible = false
            }
            scores.append(
                ModeScore(
                    id: await idGenerator.makeID(),
                    mode: mode,
                    rawScore: rawScore,
                    normalizedScore: normalizer.normalize(rawScore: rawScore),
                    positiveContributors: modeVotes.filter { $0.finalContribution > 0 },
                    negativeContributors: modeVotes.filter { $0.finalContribution < 0 },
                    exclusionReasons: exclusionReasons,
                    isEligible: isEligible
                )
            )
        }

        // Stage 11: stable ranking — descending normalized, then raw, then mode.
        scores.sort { lhs, rhs in
            if lhs.normalizedScore != rhs.normalizedScore { return lhs.normalizedScore > rhs.normalizedScore }
            if lhs.rawScore != rhs.rawScore { return lhs.rawScore > rhs.rawScore }
            return lhs.mode.rawValue < rhs.mode.rawValue
        }
        let eligible = scores.filter(\.isEligible)
        let rawWinnerWasExcluded = scores.first.map { !$0.isEligible } ?? false

        guard let winner = eligible.first else {
            return await unchangedDecision(
                outcome: .blockedByUserPreference,
                reason: "Every candidate mode is currently disabled in your settings.",
                snapshot: snapshot, history: history, preferences: preferences,
                scores: scores, ignoredSignals: ignoredSignals, evaluationTime: evaluationTime
            )
        }
        let runnerUpScore = eligible.dropFirst().first?.normalizedScore ?? 0.0
        let winnerVotes = (winner.positiveContributors + winner.negativeContributors)

        // Stage 12: confidence.
        let analyzer = SignalContributionAnalyzer(
            contributionEpsilon: configuration.contributionEpsilon,
            conflictContributionThreshold: configuration.conflictContributionThreshold
        )
        let otherEligibleVotes = eligible.dropFirst().flatMap { $0.positiveContributors }
        let independentCount = analyzer.independentContributingSignalCount(winnerVotes: winnerVotes)
        let conflictingCount = analyzer.conflictingSignalCount(
            winnerVotes: winnerVotes,
            otherEligibleModeVotes: Array(otherEligibleVotes)
        )
        let reliability = ContributionWeightedReliabilityCalculator(
            contributionEpsilon: configuration.contributionEpsilon
        ).calculate(votes: analyzer.reliabilityInputs(winnerVotes: winnerVotes))

        let signalsByID = Dictionary(uniqueKeysWithValues: validSignals.map { ($0.id, $0) })
        let freshnessInputs = winnerVotes.compactMap { vote -> FreshnessCalculator.SignalFreshnessInput? in
            guard let signal = signalsByID[vote.signalID] else { return nil }
            return FreshnessCalculator.SignalFreshnessInput(
                contribution: vote.finalContribution,
                age: max(0, evaluationTime.timeIntervalSince(signal.timestamp)),
                maxUsefulAge: scoring.usefulAge(for: signal.kind)
            )
        }
        let freshness = FreshnessCalculator(contributionEpsilon: configuration.contributionEpsilon)
            .calculate(inputs: freshnessInputs)

        let personalizationInfluenced = winnerVotes.contains { $0.preferenceModifier != 1.0 }
        let explicitInputFactor: Double
        if history.activeOverride?.isActive(at: evaluationTime) == true {
            explicitInputFactor = 1.0
        } else if preferences.hasRecentExplicitCheckIn || snapshot.moodSource == .manualCheckIn {
            explicitInputFactor = 0.80
        } else if personalizationInfluenced {
            explicitInputFactor = 0.40
        } else {
            explicitInputFactor = 0.0
        }

        // Missing-component handling (B.8): never renormalize the formula.
        // Missing components contribute nothing, and evidenceCoverage scales
        // the result down; below minimum coverage the result may not exceed
        // the suggestion threshold.
        let confidenceConfig = configuration.confidenceConfiguration
        var availableWeight = confidenceConfig.winningScoreWeight
            + confidenceConfig.scoreMarginWeight
            + confidenceConfig.independentSignalsWeight
            + confidenceConfig.explicitInputWeight
        if reliability != nil { availableWeight += confidenceConfig.reliabilityWeight }
        if freshness != nil { availableWeight += confidenceConfig.freshnessWeight }
        let totalWeight = confidenceConfig.winningScoreWeight + confidenceConfig.scoreMarginWeight
            + confidenceConfig.reliabilityWeight + confidenceConfig.independentSignalsWeight
            + confidenceConfig.freshnessWeight + confidenceConfig.explicitInputWeight
        let evidenceCoverage = availableWeight / totalWeight

        var confidence = ConfidenceCalculator(configuration: confidenceConfig).calculate(
            input: ConfidenceInput(
                winningScore: winner.normalizedScore,
                runnerUpScore: runnerUpScore,
                averageReliability: reliability ?? 0.0,
                independentSignalCount: independentCount,
                conflictingSignalCount: conflictingCount,
                freshnessFactor: freshness ?? 0.0,
                explicitInputFactor: explicitInputFactor
            )
        )
        if evidenceCoverage < 1.0 {
            var adjusted = confidence.overall * evidenceCoverage
            if evidenceCoverage < configuration.minimumEvidenceCoverage {
                adjusted = min(adjusted, configuration.suggestionConfidence)
            }
            confidence = replacingOverall(confidence, overall: adjusted)
        }
        // A thin evidence base never auto-applies, regardless of score.
        if independentCount < configuration.minimumIndependentSignals {
            confidence = replacingOverall(
                confidence,
                overall: min(confidence.overall, configuration.automaticAdaptationConfidence)
            )
        }

        // Stages 13–17: outcome, hysteresis, cooldown, override rules.
        let selector = AdaptationOutcomeSelector(configuration: confidenceConfig)
        var outcome = selector.outcome(for: confidence.overall)
        var selectedMode = winner.mode
        var stabilityNote: String?

        let currentScore = scores.first { $0.mode == history.currentMode }?.normalizedScore ?? 0.5
        let moodInferredOnly = snapshot.moodSource == .interactionEstimate

        if let override = history.activeOverride, override.isActive(at: evaluationTime) {
            // Manual override wins; the engine keeps evaluating but never
            // replaces the manual mode (B.12).
            selectedMode = override.mode
            outcome = .blockedByManualOverride
            stabilityNote = "You chose \(override.mode.displayName) yourself, so automatic changes are paused."
        } else if winner.mode == history.currentMode {
            selectedMode = history.currentMode
            if outcome == .applied || outcome == .suggested {
                outcome = .unchangedInsufficientDifference
                stabilityNote = "\(history.currentMode.displayName) is still the best match, so nothing changed."
            }
        } else if outcome == .applied || outcome == .suggested {
            let hysteresis = HysteresisPolicy(configuration: configuration)
            let cooldown = CooldownPolicy(configuration: configuration)
            if !hysteresis.candidateClears(
                candidateScore: winner.normalizedScore,
                currentModeScore: currentScore,
                candidate: winner.mode,
                moodIsInferredOnly: moodInferredOnly
            ) {
                selectedMode = history.currentMode
                outcome = .unchangedInsufficientDifference
                stabilityNote = "\(winner.mode.displayName) scored close to \(history.currentMode.displayName), "
                    + "but not clearly enough to justify a switch."
            } else if outcome == .applied {
                if cooldown.isCoolingDown(at: evaluationTime, history: history, candidate: winner.mode) {
                    selectedMode = history.currentMode
                    outcome = .unchangedCooldown
                    stabilityNote = "A recent automatic change is still settling, so the interface stayed put."
                } else if !preferences.automaticAdaptationEnabled {
                    outcome = .suggested
                    stabilityNote = "Automatic adaptation is off, so this is offered as a suggestion."
                }
            }
        } else if outcome == .unchangedLowConfidence {
            selectedMode = history.currentMode
            if rawWinnerWasExcluded {
                outcome = .blockedByUserPreference
                stabilityNote = "The strongest candidate is one you disabled, and nothing else was compelling."
            }
        }
        if outcome == .unchangedLowConfidence {
            selectedMode = history.currentMode
        }

        // Stage: secondary modifiers (accessibility/thermal/power — allowed
        // to change even during cooldown or override).
        let signalKindsPresent = Set(validSignals.map(\.kind))
        let modifiers = AdaptationModifiers(
            reduceMotion: signalKindsPresent.contains(.reducedMotionPreference)
                || signalKindsPresent.contains(.thermalPressure)
                || signalKindsPresent.contains(.lowPowerMode),
            increaseContrast: signalKindsPresent.contains(.increasedContrastPreference)
                || signalKindsPresent.contains(.highAmbientVisibility),
            increaseTextScale: signalKindsPresent.contains(.largeTextPreference),
            reduceVisualComplexity: signalKindsPresent.contains(.thermalPressure)
                || signalKindsPresent.contains(.lowPowerMode)
                || preferences.reducedStimulationPreferred,
            reduceHaptics: signalKindsPresent.contains(.thermalPressure)
                || selectedMode == .sleepPreparation || selectedMode == .lowStimulation,
            reduceMediaIntensity: signalKindsPresent.contains(.lateNight)
                || selectedMode == .lowStimulation || selectedMode == .sleepPreparation
        )

        let baseTheme = AdaptiveTheme.base(for: selectedMode)
        let resolvedTheme = themeComposer.compose(
            baseTheme: baseTheme,
            modifiers: modifiers,
            accessibility: snapshot.accessibility,
            environment: snapshot.environment,
            powerContext: snapshot.power,
            preferences: preferences
        )

        // Stage 18: explainability record.
        let explanation = await buildExplanation(
            evaluationTime: evaluationTime,
            selectedMode: selectedMode,
            candidate: winner,
            outcome: outcome,
            confidence: confidence,
            winnerVotes: winnerVotes,
            signalsByID: signalsByID,
            ignoredSignals: ignoredSignals,
            snapshot: snapshot,
            history: history,
            stabilityNote: stabilityNote
        )

        let interventions = await suggestedInterventions(for: selectedMode, outcome: outcome)
        let reevaluateAfter: TimeInterval
        if snapshot.power.thermalPressure == .serious || snapshot.power.thermalPressure == .critical {
            // Longer interval under thermal pressure (B.15) — less work, not more.
            reevaluateAfter = configuration.defaultReevaluationInterval * 2
        } else if selectedMode == .outdoorVisibility {
            reevaluateAfter = configuration.outdoorCooldown
        } else {
            reevaluateAfter = configuration.defaultReevaluationInterval
        }

        return AdaptationDecision(
            id: await idGenerator.makeID(),
            evaluatedAt: evaluationTime,
            previousMode: history.currentMode,
            selectedMode: selectedMode,
            outcome: outcome,
            modeScores: scores,
            confidence: confidence,
            theme: resolvedTheme.effective,
            resolvedTheme: resolvedTheme,
            modifiers: modifiers,
            suggestedInterventions: interventions,
            explanation: explanation,
            reevaluateAfter: reevaluateAfter,
            manualOverride: history.activeOverride?.isActive(at: evaluationTime) == true
                ? history.activeOverride
                : nil
        )
    }

    // MARK: - Helpers

    private func stableVoteOrder(_ lhs: ModeVote, _ rhs: ModeVote) -> Bool {
        let lhsAbs = abs(lhs.finalContribution)
        let rhsAbs = abs(rhs.finalContribution)
        if lhsAbs != rhsAbs { return lhsAbs > rhsAbs }
        if lhs.signalKind != rhs.signalKind { return lhs.signalKind.rawValue < rhs.signalKind.rawValue }
        if lhs.mode != rhs.mode { return lhs.mode.rawValue < rhs.mode.rawValue }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func replacingOverall(_ confidence: DecisionConfidence, overall: Double) -> DecisionConfidence {
        DecisionConfidence(
            overall: min(max(overall, 0.0), 1.0),
            winningScore: confidence.winningScore,
            runnerUpScore: confidence.runnerUpScore,
            normalizedScoreMargin: confidence.normalizedScoreMargin,
            averageReliability: confidence.averageReliability,
            independentSignalFactor: confidence.independentSignalFactor,
            freshnessFactor: confidence.freshnessFactor,
            explicitInputFactor: confidence.explicitInputFactor,
            conflictPenalty: confidence.conflictPenalty,
            independentSignalCount: confidence.independentSignalCount,
            conflictingSignalCount: confidence.conflictingSignalCount
        )
    }

    private func buildExplanation(
        evaluationTime: Date,
        selectedMode: AdaptiveMode,
        candidate: ModeScore,
        outcome: AdaptationOutcome,
        confidence: DecisionConfidence,
        winnerVotes: [ModeVote],
        signalsByID: [UUID: ContextSignal],
        ignoredSignals: [IgnoredSignal],
        snapshot: ContextSnapshot,
        history: AdaptationHistory,
        stabilityNote: String?
    ) async -> AdaptationExplanation {
        let contributing = winnerVotes
            .filter { abs($0.finalContribution) > configuration.contributionEpsilon }
            .sorted { stableVoteOrder($0, $1) }

        var positiveFactors: [ExplanationFactor] = []
        var negativeFactors: [ExplanationFactor] = []
        for vote in contributing.prefix(8) {
            let signal = signalsByID[vote.signalID]
            let factor = ExplanationFactor(
                id: await idGenerator.makeID(),
                title: title(for: vote.signalKind),
                explanation: vote.explanation,
                contribution: vote.finalContribution,
                source: signal?.source ?? .simulation,
                isApproximation: signal?.isApproximation ?? false,
                signalKind: vote.signalKind
            )
            if vote.finalContribution >= 0 {
                positiveFactors.append(factor)
            } else {
                negativeFactors.append(factor)
            }
        }

        let usedSources = Set(contributing.compactMap { signalsByID[$0.signalID]?.source })
            .sorted { $0.rawValue < $1.rawValue }
        let unusedSources = ContextSignalSource.allCases
            .filter { !usedSources.contains($0) }
            .sorted { $0.rawValue < $1.rawValue }

        var unavailable: [UnavailableSignal] = []
        if snapshot.weather == nil {
            unavailable.append(UnavailableSignal(name: "Weather", reason: "Weather data was not available."))
        }
        if snapshot.sleepDurationHours == nil {
            unavailable.append(UnavailableSignal(name: "Sleep", reason: "No sleep data was available or authorized."))
        }
        if snapshot.moodValence == nil {
            unavailable.append(UnavailableSignal(name: "Mood", reason: "No recent mood check-in."))
        }

        let headline: String
        let summary: String
        switch outcome {
        case .applied:
            headline = "Switched to \(selectedMode.displayName)"
            summary = "Your current signals strongly support \(selectedMode.displayName). "
                + (positiveFactors.first?.explanation ?? "")
        case .suggested:
            headline = "\(selectedMode.displayName) might help right now"
            summary = "The evidence points toward \(selectedMode.displayName), but not strongly enough "
                + "to switch without asking. You decide."
        case .unchangedLowConfidence:
            headline = "Staying in \(history.currentMode.displayName)"
            summary = "Your current signals do not strongly support a different mode, "
                + "so the interface was left unchanged."
        case .unchangedCooldown:
            headline = "Staying in \(history.currentMode.displayName) for now"
            summary = stabilityNote ?? "A recent change is still settling."
        case .unchangedInsufficientDifference:
            headline = "Staying in \(history.currentMode.displayName)"
            summary = stabilityNote ?? "No candidate was clearly better than the current mode."
        case .blockedByManualOverride:
            headline = "Keeping your choice: \(selectedMode.displayName)"
            summary = stabilityNote ?? "You selected this mode manually."
        case .blockedByUserPreference:
            headline = "Staying in \(history.currentMode.displayName)"
            summary = stabilityNote ?? "Your settings prevent this change."
        case .blockedByCapability:
            headline = "Staying in \(history.currentMode.displayName)"
            summary = "This change is not possible on this device."
        }

        return AdaptationExplanation(
            id: await idGenerator.makeID(),
            generatedAt: evaluationTime,
            headline: headline,
            summary: summary,
            selectedMode: selectedMode,
            outcome: outcome,
            confidence: confidence,
            topPositiveFactors: positiveFactors,
            topNegativeFactors: negativeFactors,
            ignoredSignals: ignoredSignals,
            unavailableSignals: unavailable,
            privacySummary: "All of this was evaluated on your device. Nothing left it.",
            dataSourcesUsed: usedSources,
            dataSourcesNotUsed: unusedSources,
            undoDescription: outcome == .applied
                ? "Tap Undo to return to \(history.currentMode.displayName) immediately."
                : "No change was applied, so there is nothing to undo."
        )
    }

    /// Terminal path when no candidate is even eligible: keep the current
    /// mode with a complete, valid explanation.
    private func unchangedDecision(
        outcome: AdaptationOutcome,
        reason: String,
        snapshot: ContextSnapshot,
        history: AdaptationHistory,
        preferences: AdaptivePreferences,
        scores: [ModeScore],
        ignoredSignals: [IgnoredSignal],
        evaluationTime: Date
    ) async -> AdaptationDecision {
        let confidence = DecisionConfidence(
            overall: 0.0, winningScore: 0.0, runnerUpScore: 0.0, normalizedScoreMargin: 0.0,
            averageReliability: 0.0, independentSignalFactor: 0.0, freshnessFactor: 0.0,
            explicitInputFactor: 0.0, conflictPenalty: 1.0,
            independentSignalCount: 0, conflictingSignalCount: 0
        )
        let baseTheme = AdaptiveTheme.base(for: history.currentMode)
        let resolvedTheme = themeComposer.compose(
            baseTheme: baseTheme,
            modifiers: .none,
            accessibility: snapshot.accessibility,
            environment: snapshot.environment,
            powerContext: snapshot.power,
            preferences: preferences
        )
        let explanation = AdaptationExplanation(
            id: await idGenerator.makeID(),
            generatedAt: evaluationTime,
            headline: "Staying in \(history.currentMode.displayName)",
            summary: reason,
            selectedMode: history.currentMode,
            outcome: outcome,
            confidence: confidence,
            topPositiveFactors: [],
            topNegativeFactors: [],
            ignoredSignals: ignoredSignals,
            unavailableSignals: [],
            privacySummary: "All of this was evaluated on your device. Nothing left it.",
            dataSourcesUsed: [],
            dataSourcesNotUsed: ContextSignalSource.allCases.sorted { $0.rawValue < $1.rawValue },
            undoDescription: "No change was applied, so there is nothing to undo."
        )
        return AdaptationDecision(
            id: await idGenerator.makeID(),
            evaluatedAt: evaluationTime,
            previousMode: history.currentMode,
            selectedMode: history.currentMode,
            outcome: outcome,
            modeScores: scores,
            confidence: confidence,
            theme: resolvedTheme.effective,
            resolvedTheme: resolvedTheme,
            modifiers: .none,
            suggestedInterventions: [],
            explanation: explanation,
            reevaluateAfter: configuration.defaultReevaluationInterval,
            manualOverride: nil
        )
    }

    private func title(for kind: ContextSignalKind) -> String {
        switch kind {
        case .lateNight: return "Late night"
        case .earlyMorning: return "Early morning"
        case .daytime: return "Daytime"
        case .solarBrightness: return "Sun position"
        case .outdoorLikelihood: return "Likely outdoors"
        case .lowAmbientVisibility: return "Dark surroundings"
        case .highAmbientVisibility: return "Bright surroundings"
        case .poorSleep: return "Short sleep"
        case .goodSleep: return "Good sleep"
        case .lowEnergy: return "Low energy"
        case .highEnergy: return "High energy"
        case .negativeValence: return "Difficult mood"
        case .positiveValence: return "Positive mood"
        case .reportedStress: return "Reported stress"
        case .reportedCalm: return "Reported calm"
        case .interactionFatigue: return "Screen fatigue"
        case .prolongedSession: return "Long session"
        case .rapidNavigation: return "Rapid navigation"
        case .upcomingInterview: return "Upcoming interview"
        case .activeFocusGoal: return "Focus goal"
        case .physicalActivity: return "Physical activity"
        case .inactivity: return "Little movement"
        case .rainyWeather: return "Rainy weather"
        case .pleasantWeather: return "Pleasant weather"
        case .highUV: return "High UV"
        case .thermalPressure: return "Device temperature"
        case .lowPowerMode: return "Low Power Mode"
        case .reducedMotionPreference: return "Reduce Motion"
        case .increasedContrastPreference: return "Increase Contrast"
        case .largeTextPreference: return "Larger text"
        case .manualModeRequest: return "Your selection"
        }
    }

    private func suggestedInterventions(
        for mode: AdaptiveMode,
        outcome: AdaptationOutcome
    ) async -> [Intervention] {
        guard outcome == .applied || outcome == .suggested else { return [] }
        switch mode {
        case .eyeComfort:
            return [
                Intervention(
                    id: await idGenerator.makeID(), kind: .eyeRest,
                    title: "Rest your eyes",
                    detail: "Look at something at least 20 feet away for 20 seconds."
                ),
                Intervention(
                    id: await idGenerator.makeID(), kind: .takeBreak,
                    title: "Short break",
                    detail: "You have been at this a while — a few minutes away can help."
                ),
            ]
        case .sleepPreparation:
            return [
                Intervention(
                    id: await idGenerator.makeID(), kind: .prepareForSleep,
                    title: "Wind down",
                    detail: "Consider putting the phone down soon."
                ),
            ]
        case .recovery, .calm:
            return [
                Intervention(
                    id: await idGenerator.makeID(), kind: .breathe,
                    title: "Take a breath",
                    detail: "A slow minute of breathing can reset the pace."
                ),
            ]
        case .focus:
            return [
                Intervention(
                    id: await idGenerator.makeID(), kind: .startFocusSession,
                    title: "Start a focus session",
                    detail: "Set a duration and keep distractions out."
                ),
            ]
        case .interviewPreparation:
            return [
                Intervention(
                    id: await idGenerator.makeID(), kind: .reviewInterviewNotes,
                    title: "Review your notes",
                    detail: "A calm read-through beats last-minute cramming."
                ),
            ]
        default:
            return []
        }
    }
}

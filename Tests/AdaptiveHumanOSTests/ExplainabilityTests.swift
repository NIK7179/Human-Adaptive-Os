import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Explainability contract validation (Section B.18).
struct ExplainabilityTests {
    private let validator = ExplanationValidator()

    private func makeConfidence() -> DecisionConfidence {
        DecisionConfidence(
            overall: 0.68, winningScore: 0.85, runnerUpScore: 0.79, normalizedScoreMargin: 0.25,
            averageReliability: 0.94, independentSignalFactor: 1.0, freshnessFactor: 0.96,
            explicitInputFactor: 0.8, conflictPenalty: 0.92,
            independentSignalCount: 5, conflictingSignalCount: 1
        )
    }

    private func makeFactor(contribution: Double = 0.7, explanation: String = "It is late at night.") -> ExplanationFactor {
        ExplanationFactor(
            id: TestSupport.uuid(30), title: "Late night", explanation: explanation,
            contribution: contribution, source: .solarModel, isApproximation: false,
            signalKind: .lateNight
        )
    }

    private func makeExplanation(
        headline: String = "Eye Comfort might help right now",
        summary: String = "The evidence points toward Eye Comfort.",
        outcome: AdaptationOutcome = .suggested,
        factors: [ExplanationFactor]? = nil,
        undo: String = "Tap Undo to return to Balanced.",
        used: [ContextSignalSource] = [.solarModel],
        unused: [ContextSignalSource] = [.weatherKit]
    ) -> AdaptationExplanation {
        AdaptationExplanation(
            id: TestSupport.uuid(31), generatedAt: TestSupport.referenceDate,
            headline: headline, summary: summary, selectedMode: .eyeComfort, outcome: outcome,
            confidence: makeConfidence(),
            topPositiveFactors: factors ?? [makeFactor()], topNegativeFactors: [],
            ignoredSignals: [], unavailableSignals: [],
            privacySummary: "Evaluated on device.", dataSourcesUsed: used,
            dataSourcesNotUsed: unused, undoDescription: undo
        )
    }

    @Test
    func wellFormedExplanationValidates() throws {
        try validator.validate(explanation: makeExplanation(), contributingSources: [.solarModel])
    }

    @Test
    func emptyHeadlineIsRejected() {
        #expect(throws: ExplanationValidationError.emptyHeadline) {
            try validator.validate(
                explanation: makeExplanation(headline: "   "), contributingSources: [.solarModel]
            )
        }
    }

    @Test
    func emptySummaryIsRejected() {
        #expect(throws: ExplanationValidationError.emptySummary) {
            try validator.validate(
                explanation: makeExplanation(summary: ""), contributingSources: [.solarModel]
            )
        }
    }

    // 27. Validation rejects a suggested/applied adaptation with no
    // contributing factor.
    @Test
    func adaptationWithoutContributingFactorIsRejected() {
        #expect(throws: ExplanationValidationError.adaptationWithoutContributingFactor) {
            try validator.validate(
                explanation: makeExplanation(factors: []), contributingSources: []
            )
        }
        // Sub-epsilon contributions do not count as contributing.
        #expect(throws: ExplanationValidationError.adaptationWithoutContributingFactor) {
            try validator.validate(
                explanation: makeExplanation(factors: [makeFactor(contribution: 0.00001)]),
                contributingSources: [.solarModel]
            )
        }
    }

    @Test
    func missingUndoInstructionsAreRejectedForAppliedAdaptations() {
        #expect(throws: ExplanationValidationError.missingUndoInstructions) {
            try validator.validate(
                explanation: makeExplanation(outcome: .applied, undo: " "),
                contributingSources: [.solarModel]
            )
        }
    }

    // 28. Explanation sources must match the actual contributing signals.
    @Test
    func dataSourceMismatchIsRejected() {
        #expect(throws: ExplanationValidationError.dataSourceMismatch) {
            try validator.validate(
                explanation: makeExplanation(used: [.solarModel, .healthKit]),
                contributingSources: [.solarModel]
            )
        }
    }

    @Test
    func claimingUnavailableSourcesIsRejected() {
        #expect(throws: ExplanationValidationError.claimsUnavailableInformation) {
            try validator.validate(
                explanation: makeExplanation(used: [.solarModel], unused: [.solarModel]),
                contributingSources: [.solarModel]
            )
        }
    }

    // 35. Prohibited diagnostic language is rejected.
    @Test
    func prohibitedDiagnosticLanguageIsRejected() {
        let diagnostic = makeExplanation(
            summary: "You seem depressed, so the interface was dimmed."
        )
        #expect(throws: ExplanationValidationError.prohibitedDiagnosticLanguage(term: "depress")) {
            try validator.validate(explanation: diagnostic, contributingSources: [.solarModel])
        }
    }

    @Test
    func unchangedOutcomesNeedNoFactorsButStillNeedProse() throws {
        let unchanged = AdaptationExplanation(
            id: TestSupport.uuid(32), generatedAt: TestSupport.referenceDate,
            headline: "Staying in Balanced",
            summary: "Your current signals do not strongly support a different mode, "
                + "so the interface was left unchanged.",
            selectedMode: .balanced, outcome: .unchangedLowConfidence,
            confidence: makeConfidence(),
            topPositiveFactors: [], topNegativeFactors: [],
            ignoredSignals: [], unavailableSignals: [],
            privacySummary: "Evaluated on device.", dataSourcesUsed: [],
            dataSourcesNotUsed: [.weatherKit], undoDescription: "Nothing to undo."
        )
        try validator.validate(explanation: unchanged, contributingSources: [])
    }
}

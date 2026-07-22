import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Section A.10 — dedicated normalization coverage.
struct NormalizationTests {
    @Test
    func eyeComfortRawScoreNormalizesCorrectly() {
        let normalized = 1.0 / (1.0 + exp(-1.7582))
        #expect(abs(normalized - 0.852984) < 1e-6)
    }

    @Test
    func productionNormalizerMatchesClosedForm() {
        let normalizer = LogisticScoreNormalizer(temperature: 1.0)
        #expect(abs(normalizer.normalize(rawScore: 1.7582) - 0.852984) < 1e-6)
    }

    @Test
    func zeroRawScoreNormalizesToOneHalf() {
        let normalizer = LogisticScoreNormalizer(temperature: 1.0)
        #expect(abs(normalizer.normalize(rawScore: 0.0) - 0.5) < 1e-12)
    }

    @Test
    func normalizationIsBoundedAndMonotonic() {
        let normalizer = LogisticScoreNormalizer(temperature: 1.0)
        // ±30 is far beyond any reachable raw score (the vote table bounds
        // sums to roughly ±3) while staying below double-precision
        // saturation: at raw ≥ 37, 1 + exp(-raw) == 1.0 exactly, so the
        // logistic returns 1.0 and a strict upper-bound check would fail.
        let inputs: [Double] = [-30, -5, -1, -0.1, 0, 0.1, 1, 5, 30]
        var previous = -Double.infinity
        for raw in inputs {
            let value = normalizer.normalize(rawScore: raw)
            #expect(value > 0.0 && value < 1.0)
            #expect(value > previous)
            previous = value
        }
    }

    @Test
    func temperatureCompressesLargeScores() {
        // Design intent (B.6A): large positive raw scores compress so two
        // strongly-supported modes yield a small normalized margin.
        let normalizer = LogisticScoreNormalizer(temperature: 1.0)
        let a = normalizer.normalize(rawScore: 3.0)
        let b = normalizer.normalize(rawScore: 4.0)
        let c = normalizer.normalize(rawScore: 0.0)
        let d = normalizer.normalize(rawScore: 1.0)
        #expect((b - a) < (d - c))
    }
}

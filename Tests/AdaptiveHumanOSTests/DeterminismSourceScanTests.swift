import Testing
import Foundation
@testable import AdaptiveHumanOS

/// Section A gate: confirms no direct `Date()` / `UUID()` (or other ambient
/// nondeterminism) appears in the core scoring/confidence code paths.
/// `Core/Determinism.swift` is the single sanctioned home of the
/// system-backed implementations and is therefore exempt.
struct DeterminismSourceScanTests {
    private static let exemptFiles: Set<String> = ["Determinism.swift"]
    private static let forbiddenPatterns = [
        "Date()",
        "UUID()",
        "Date.now",
        "Calendar.current",
        "TimeZone.current",
        "Locale.current",
        "ContinuousClock()",
        "Task.sleep",
    ]

    private func coreSourceFiles() throws -> [URL] {
        // Tests/AdaptiveHumanOSTests/<this file> → package root is two levels up.
        let thisFile = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let coreSources = packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("AdaptiveHumanOS")
        let enumerator = FileManager.default.enumerator(
            at: coreSources,
            includingPropertiesForKeys: nil
        )
        var files: [URL] = []
        while let next = enumerator?.nextObject() as? URL {
            if next.pathExtension == "swift" {
                files.append(next)
            }
        }
        try #require(!files.isEmpty, "Source scan found no core files — path layout changed?")
        return files
    }

    @Test
    func coreScoringPathsContainNoAmbientNondeterminism() throws {
        for file in try coreSourceFiles() {
            if Self.exemptFiles.contains(file.lastPathComponent) { continue }
            let contents = try String(contentsOf: file, encoding: .utf8)
            for pattern in Self.forbiddenPatterns {
                #expect(
                    !contents.contains(pattern),
                    "\(file.lastPathComponent) contains forbidden ambient call `\(pattern)`"
                )
            }
        }
    }

    @Test
    func sequentialIDGeneratorHandsOutConfiguredSequence() async {
        let ids = [TestSupport.uuid(7), TestSupport.uuid(8), TestSupport.uuid(9)]
        let generator = SequentialIDGenerator(identifiers: ids)
        let first = await generator.makeID()
        let second = await generator.makeID()
        let third = await generator.makeID()
        #expect([first, second, third] == ids)
    }

    @Test
    func fixedClockReportsConfiguredInstant() {
        #expect(TestSupport.clock.now == TestSupport.referenceDate)
    }
}

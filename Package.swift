// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AdaptiveHumanOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AdaptiveHumanOS", targets: ["AdaptiveHumanOS"]),
        .library(name: "AdaptiveHumanOSUI", targets: ["AdaptiveHumanOSUI"]),
        .library(name: "AdaptiveExperienceKit", targets: ["AdaptiveExperienceKit"]),
    ],
    targets: [
        // Platform-agnostic decision engine. Foundation only — compiles and
        // tests on Linux, macOS and iOS. No SwiftUI, no UIKit, no Apple-only
        // frameworks. This is the target CI exercises with `swift test`.
        .target(
            name: "AdaptiveHumanOS"
        ),
        // Partner SDK concept: voluntary theme adoption for participating
        // apps. Never performs runtime injection into other apps.
        .target(
            name: "AdaptiveExperienceKit",
            dependencies: ["AdaptiveHumanOS"]
        ),
        // SwiftUI layer. Every file is wrapped in `#if canImport(SwiftUI)`
        // so the target compiles (to an empty module) on Linux.
        .target(
            name: "AdaptiveHumanOSUI",
            dependencies: ["AdaptiveHumanOS", "AdaptiveExperienceKit"]
        ),
        .testTarget(
            name: "AdaptiveHumanOSTests",
            dependencies: ["AdaptiveHumanOS"]
        ),
    ]
)

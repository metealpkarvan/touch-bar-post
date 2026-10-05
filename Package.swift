// swift-tools-version: 5.7
import PackageDescription
let package = Package(name: "TouchBarPost", platforms: [.macOS(.v11)], products: [
    .executable(name: "TouchBarPost", targets: ["TouchBarPost"]),
    .library(name: "PostCore", targets: ["PostCore"]),
    .executable(name: "PostRulesTests", targets: ["PostRulesTests"])
], targets: [
    .target(name: "PostCore"),
    .executableTarget(name: "TouchBarPost", dependencies: ["PostCore"]),
    .executableTarget(name: "PostRulesTests", dependencies: ["PostCore"], path: "Tests/PostRulesTests")
], swiftLanguageVersions: [.v5])

// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "Craft829a37ca",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", exact: "1.1.1")
    ],
    targets: [
        .target(name: "CraftVoiceCore"),
        .target(name: "CraftVoiceIntegration", dependencies: ["CraftVoiceCore"]),
        .executableTarget(name: "CraftVoiceIntegrationProbe", dependencies: ["CraftVoiceIntegration", "CraftVoiceCore"], path: "Sources/IntegrationProbe"),
        .testTarget(name: "CraftVoiceIntegrationTests", dependencies: ["CraftVoiceIntegration"]),
        .executableTarget(name: "CraftVoiceModelProbe", dependencies: ["CraftVoiceCore", "CraftVoiceSpeech"], path: "Sources/ModelProbe"),
        .target(name: "CraftVoiceSpeech", dependencies: ["CraftVoiceCore", .product(name: "WhisperKit", package: "WhisperKit")]),
        .testTarget(name: "CraftVoiceSpeechTests", dependencies: ["CraftVoiceSpeech"]),
        .executableTarget(name: "CraftVoicePlatformProbe", path: "Sources/PlatformProbe"),
        .testTarget(name: "CraftVoiceCoreTests", dependencies: ["CraftVoiceCore"]),
        .target(name: "ExampleKit"),
        .executableTarget(name: "Craft829a37ca", dependencies: ["ExampleKit", "CraftVoiceCore", "CraftVoiceSpeech", "CraftVoiceIntegration"], path: "Sources/App"),
        .testTarget(name: "ExampleKitTests", dependencies: ["ExampleKit"])
    ]
)

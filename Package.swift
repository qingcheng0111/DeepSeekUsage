// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeepSeekUsage",
    platforms: [.macOS(.v14)],
    targets: [
        // 菜单栏 App（单 target）
        .executableTarget(
            name: "DeepSeekUsage",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

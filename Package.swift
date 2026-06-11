// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitLog",
    platforms: [.iOS(.v17)],
    targets: [
        .executableTarget(
            name: "FitLog",
            path: "Sources/FitLog"
        )
    ]
)

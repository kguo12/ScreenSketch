// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenSketch",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ScreenSketch", targets: ["ScreenSketch"])],
    targets: [.executableTarget(name: "ScreenSketch", path: "Sources/ScreenAnnotator")]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "snapview",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "snapview", targets: ["snapview"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.2"),
  ],
  targets: [
    .executableTarget(
      name: "snapview",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "XcodeProj", package: "XcodeProj"),
      ]
    ),
    .testTarget(
      name: "SnapviewTests",
      dependencies: ["snapview"]
    ),
  ]
)

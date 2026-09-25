// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "AirPodsSoundQualityFixerPackage",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(name: "AudioInputFixer", targets: ["AudioInputFixer"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
  ],
  targets: [
    .target(name: "AudioInputFixer"),
    .testTarget(
      name: "AudioInputFixerTests",
      dependencies: [
        "AudioInputFixer",
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ]
    ),
  ]
)

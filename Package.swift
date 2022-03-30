// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "Networking",
  platforms: [
    .iOS(.v13),
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "Networking",
      targets: ["Networking"]
    ),
  ],
  dependencies: [
    .package(name: "Apollo", url: "https://github.com/apollographql/apollo-ios", .upToNextMajor(from: "0.50.0")),
  ],
  targets: [
    .target(
      name: "Networking",
      dependencies: [
        "Apollo",
      ]
    ),
  ]
)

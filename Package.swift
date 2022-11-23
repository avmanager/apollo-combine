// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "ApolloCombine",
  platforms: [
    .iOS(.v13),
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "ApolloCombine",
      targets: ["ApolloCombine"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apollographql/apollo-ios", .upToNextMajor(from: "1.0.5")),
  ],
  targets: [
    .target(
      name: "ApolloCombine",
      dependencies: [
        .product(name: "Apollo", package: "apollo-ios"),
        .product(name: "ApolloWebSocket", package: "apollo-ios"),
      ]
    ),
  ]
)

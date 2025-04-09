// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MNVaporUtils",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MNVaporUtils",
            targets: ["MNVaporUtils"]
        ),
    ],
    dependencies: [
        // 3Rd party
        .package(url: "https://github.com/vapor/vapor.git", from: "4.106.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.4.0"),
        // .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.1"),

        // In-House pakcages
//        .package(url: "https://gitlab.com/ido_r_demos/DSLogger.git", from:"0.0.1"),
//        .package(url: "https://gitlab.com/ido_r_demos/MNUtils.git", from:"0.0.2"),
        .package(path: "../../xcode/MNUtils/MNUtils"),
        .package(path: "../../xcode/DSLogger/"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MNVaporUtils",
            dependencies: [
                // 3Rd party
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Vapor", package: "vapor"),
                // .product(name: "JWT", package: "jwt-kit"),

                // In-House pakcages
                .product(name: "DSLogger", package: "DSLogger"),
                .product(name: "MNUtils", package: "MNUtils"),
            ],
            swiftSettings: [
                // Enables better optimizations when building in Release
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),

                .define("PRODUCTION", .when(configuration: .release)),
                .define("DEBUG", .when(configuration: .debug)),
                .define("VAPOR"),
                .define("NIO"),
                .define("FLUENT"),
            ]
        ),
        .testTarget(
            name: "MNVaporUtilsTests",
            dependencies: ["MNVaporUtils"]
        ),
    ]
)

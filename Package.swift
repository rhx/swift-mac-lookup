// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MACLookup",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "MACLookup",
            targets: ["MACLookup"]
        ),
        .executable(
            name: "hwaddrlookup",
            targets: ["hwaddrlookup"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "MACLookup"
        ),
        .testTarget(
            name: "MACLookupTests",
            dependencies: ["MACLookup"],
            resources: [
                .copy("Resources/testoui.txt")
            ]
        ),
        .executableTarget(
            name: "hwaddrlookup",
            dependencies: [
                "MACLookup",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)

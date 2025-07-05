// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MACLookup",
    products: [
        .library(
            name: "MACLookup",
            targets: ["MACLookup"]
        ),
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
    ]
)

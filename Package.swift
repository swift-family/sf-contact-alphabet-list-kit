// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sf-contact-alphabet-list-kit",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .library(
            name: "SFContactAlphabetListKit",
            targets: ["SFContactAlphabetListKit"]
        )
    ],
    targets: [
        .target(
            name: "SFContactAlphabetListKit"
        )
    ]
)

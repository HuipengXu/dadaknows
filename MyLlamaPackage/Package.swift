// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MyLlamaPackage",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MyLlamaPackage",
            targets: ["MyLlamaPackage"]
        )
    ],
    targets: [
        .target(
            name: "MyLlamaPackage",
            dependencies: ["LlamaFramework"]
        ),
        .binaryTarget(
            name: "LlamaFramework",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b6548/llama-b6548-xcframework.zip",
            checksum: "4242cda8b37d274634c58d31329b238c15544a95b9952abffebbda62a1cdde45"
        )
    ]
)

// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyProxyCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "SwiftyProxyCore",
            targets: ["SwiftyProxyCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.0.0"),
        .package(url: "https://github.com/f-meloni/SwiftBrotli", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "SwiftyProxyCore",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
                .product(name: "SwiftBrotli", package: "SwiftBrotli"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .testTarget(name: "SwiftyProxyCoreTests")
    ]
)

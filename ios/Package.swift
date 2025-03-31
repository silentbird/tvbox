// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TVBox",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "TVBox",
            targets: ["TVBox"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.1"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "TVBox",
            dependencies: [
                "Alamofire",
                "SnapKit",
                "Kingfisher",
                "SwiftyJSON"
            ]),
        .testTarget(
            name: "TVBoxTests",
            dependencies: ["TVBox"]),
    ]
) 
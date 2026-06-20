// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "netcutx",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NetcutxBPF", targets: ["NetcutxBPF"]),
    ],
    targets: [
        .target(
            name: "NetcutxBPF_C",
            dependencies: [],
            linkerSettings: []
        ),
        .target(
            name: "NetcutxBPF",
            dependencies: ["NetcutxBPF_C"]
        ),
    ]
)

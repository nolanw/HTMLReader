// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "HTMLReader",
    products: [.library(name: "HTMLReader", targets: ["HTMLReader"])],
    targets: [.target(name: "HTMLReader", dependencies: [], path: "Sources")])

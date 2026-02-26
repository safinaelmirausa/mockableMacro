// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
	name: "MockableMacro",
	platforms: [.iOS(.v15), .macOS(.v13)],
	products: [
		.library(
			name: "MockableClient",
			targets: ["MockableClient"]
		),
	],
	dependencies: [
		// ⬇⬇⬇ откат до стабильной версии
		.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
	],
	targets: [
		.target(
			name: "MockableClient",
			dependencies: ["MockableImpl"]
		),
		.macro(
			name: "MockableImpl",
			dependencies: [
				.product(name: "SwiftSyntax", package: "swift-syntax"),
				.product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"), // ✅ доступен в 509
			],
			swiftSettings: [
				.enableExperimentalFeature("MacroExpansion") // 🔹 позволяет Xcode видеть автокомплишен
			]
		)
	]
)

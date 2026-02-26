//
//  MockablePlugin.swift
//  MockableMacro
//
//  Created by Eli Safina on 09/10/25.
//
//  MARK: - Description
//  This file registers all compiler macros provided by the library
//  as part of a Swift Compiler Plugin.
//
//  The plugin acts as an entry point for the Swift compiler and
//  enables macro expansion during compilation whenever the user
//  applies annotations such as `@Mockable` or `@Mask`.
//
//  Project structure:
//      MockableClient.swift  → public macro declarations (API surface)
//      Mockable.swift        → implementation of `@Mockable` macro
//      MaskMacro.swift       → implementation of `@Mask` macro
//      MockablePlugin.swift  → compiler plugin entry point & registration
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// Main entry point for the Swift Compiler Plugin.
///
/// `MockablePlugin` registers all macros implemented by this package
/// so that the Swift compiler can expand them during compilation.
///
/// This type contains **no business logic**.
/// Its sole responsibility is to expose macro implementations
/// to the compiler infrastructure.
@main
struct MockablePlugin: CompilerPlugin {

	/// List of macros provided by this compiler plugin.
	///
	/// - `MockableMacro` — generates mock initializers and factory methods
	/// - `MaskMacro`     — generates masked value accessors for properties
	let providingMacros: [Macro.Type] = [
		MockableMacro.self,
		MaskMacro.self
	]
}

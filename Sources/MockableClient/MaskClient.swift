//
//  Mask.swift
//  MockableMacro
//

import Foundation

/// Applies a masking pattern to a stored property.
///
/// The macro generates a masked value at runtime using `MaskGenerator`
/// and assigns it during mock initialization.
///
/// This macro is declared as `@attached(peer)` to allow
/// generation of additional properties if needed.
///
/// - Important: Only the `MaskPattern` enum is supported.
/// String-based masks are intentionally not exposed.
@attached(peer, names: arbitrary)
public macro Mask(_ pattern: MaskPattern) = #externalMacro(
	module: "MockableImpl",
	type: "MaskMacro"
)

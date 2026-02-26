//
//  MaskPattern.swift
//  MockableMacro
//
//  Defines supported mask patterns for the @Mask macro.
//

import Foundation

/// Describes a masking pattern used by the `@Mask` macro.
///
/// Mask patterns are used to generate fake but valid-looking data
/// for testing and previews.
///
/// ## Built-in patterns
/// - `cardNumber`   – Credit/debit card number
/// - `cardExpiry`  – Card expiration date
/// - `date`         – Date in numeric format
/// - `phoneUZ`      – Uzbekistan phone number
/// - `pinflUZ`      – Uzbekistan PINFL
/// - `passportUZ`   – Uzbekistan passport number
///
/// ## Custom pattern
/// Use `.pattern(String)` to define a custom format.
///
/// ### Pattern symbols
/// - `A` – Random uppercase Latin letter (`A–Z`)
/// - `X` – Random digit (`0–9`)
/// - Any other character is preserved as-is.
///
/// ### Example
/// ```swift
/// @Mask(.pattern("AAA XX"))
/// var code: String
/// // → "QWE 42"
/// ```
public enum MaskPattern {
	case cardNumber
	case cardExpiry
	case date
	case phoneUZ
	case pinflUZ
	case passportUZ

	/// Custom mask pattern.
	///
	/// - Parameter pattern: Pattern string using `A` and `X` symbols.
	case pattern(String)
}

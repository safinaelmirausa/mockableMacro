//
//  MaskGenerator.swift
//  MockableMacro
//
//  Created by Eli Safina on 15/12/25.
//

import Foundation

/// Runtime utility for generating masked strings based on simple patterns.
///
/// `MaskGenerator` is used internally by the `@Mask` macro,
/// but can also be used directly to generate fake, human-readable data
/// for tests, previews, and demo content.
///
/// ## Pattern symbols
/// The following symbols are supported in pattern strings:
///
/// | Symbol | Description |
/// |-------|-------------|
/// | `A` | Random uppercase Latin letter (`A–Z`) |
/// | `X` | Random digit (`0–9`) |
/// | Any other character | Preserved as-is |
///
/// > Important: Pattern symbols must be **Latin** characters.
/// > Cyrillic `А` / `Х` are visually similar but are **not supported**.
public enum MaskGenerator {

	/// Generates a masked string from a pattern.
	///
	/// The pattern string is processed character by character.
	/// Each supported symbol is replaced with a randomly generated value.
	///
	/// - Parameter pattern: A pattern string using `A` and `X` symbols.
	/// - Returns: A generated string matching the pattern.
	///
	/// ## Example
	/// ```swift
	/// MaskGenerator.fromPattern("AAA XX")
	/// // → "QWE 42"
	/// ```
	public static func fromPattern(_ pattern: String) -> String {
		var result = ""
		for ch in pattern {
			switch ch {
			case "X":
				result += randomDigit()
			case "A":
				result += randomLetter()
			default:
				result.append(ch)
			}
		}
		return result
	}

	/// Generates a random single digit (`0–9`).
	private static func randomDigit() -> String {
		String(Int.random(in: 0...9))
	}

	/// Generates a random uppercase Latin letter (`A–Z`).
	private static func randomLetter() -> String {
		let scalar = UnicodeScalar(Int.random(in: 65...90))! // A–Z
		return String(Character(scalar))
	}

	/// Generates a credit/debit card number.
	///
	/// Format:
	/// ```
	/// XXXX XXXX XXXX XXXX
	/// ```
	///
	/// Example output:
	/// ```
	/// 4355 9577 2756 9734
	/// ```
	public static func cardNumber() -> String {
		fromPattern("XXXX XXXX XXXX XXXX")
	}

	/// Generates a card expiration date.
	///
	/// Format:
	/// ```
	/// XX/XX
	/// ```
	///
	/// Example output:
	/// ```
	/// 09/27
	/// ```
	public static func cardExpiry() -> String {
		fromPattern("XX/XX")
	}

	/// Generates a numeric date string.
	///
	/// Format:
	/// ```
	/// XX-XX-XXXX
	/// ```
	///
	/// Example output:
	/// ```
	/// 12-05-2028
	/// ```
	public static func date() -> String {
		fromPattern("XX-XX-XXXX")
	}

	/// Generates a Uzbekistan phone number.
	///
	/// - Uses real mobile operator codes
	/// - Country code is always `+998`
	///
	/// Example output:
	/// ```
	/// +998 94 337 02 26
	/// ```
	public static func phoneUZ() -> String {
		let opCodes = ["90", "91", "93", "94", "95", "98", "99", "33", "88"]
		let code = opCodes.randomElement()!
		return "+998 \(code) \(fromPattern("XXX XX XX"))"
	}

	/// Generates a Uzbekistan PINFL number.
	///
	/// Format:
	/// ```
	/// XXXXXXXXXXXXXX
	/// ```
	public static func pinflUZ() -> String {
		fromPattern("XXXXXXXXXXXXXX")
	}

	/// Generates a Uzbekistan passport number.
	///
	/// Format:
	/// ```
	/// AAXXXXXXX
	/// ```
	///
	/// Example output:
	/// ```
	/// AB1234567
	/// ```
	public static func passportUZ() -> String {
		fromPattern("AAXXXXXXX")
	}
}

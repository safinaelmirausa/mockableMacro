//
//  MaskMacro.swift
//  MockableMacro
//
//  Created by Eli Safina on 09/12/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Internal enum describing built-in mask identifiers.
///
/// This enum mirrors the public `MaskPattern` cases
/// and is used internally by the compiler macro to
/// resolve which runtime generator should be called.
enum BuiltinMask: String {
	case cardNumber
	case cardExpiry
	case date
	case phoneUZ
	case pinflUZ
	case passportUZ
}

/// Generates a random digit character (`0–9`).
fileprivate func randomDigit() -> String {
	String(Int.random(in: 0...9))
}

/// Generates a random uppercase Latin letter (`A–Z`).
fileprivate func randomLetter() -> String {
	let scalar = UnicodeScalar(Int.random(in: 65...90))! // A–Z
	return String(Character(scalar))
}

/// Returns `true` if the string contains any Cyrillic characters.
///
/// This check is Unicode-based and covers all official Cyrillic ranges:
/// - U+0400–U+04FF — Cyrillic
/// - U+0500–U+052F — Cyrillic Supplement
/// - U+2DE0–U+2DFF — Cyrillic Extended-A
/// - U+A640–U+A69F — Cyrillic Extended-B
///
/// Used to detect common user mistakes where Cyrillic letters
/// (e.g. `А`, `Х`) are entered instead of visually similar
/// Latin characters (`A`, `X`) in mask patterns.
fileprivate func containsCyrillic(_ string: String) -> Bool {
	string.unicodeScalars.contains { scalar in
		(0x0400...0x04FF).contains(scalar.value) ||   // Cyrillic
		(0x0500...0x052F).contains(scalar.value) ||   // Cyrillic Supplement
		(0x2DE0...0x2DFF).contains(scalar.value) ||   // Cyrillic Extended-A
		(0xA640...0xA69F).contains(scalar.value)      // Cyrillic Extended-B
	}
}
fileprivate func logCyrillicWarning(
	pattern: String,
	propertyName: String?
) {
	let prop = propertyName.map { " for property `\($0)`" } ?? ""
	print("""
	⚠️ [MockableMacro][Mask]
	Cyrillic characters detected\(prop).

	Pattern: "\(pattern)"
	Hint: Use only Latin letters (A–Z) and digits (X).

	Example:
	  "AA-XXXX" ✅
	  "АА-ХХХХ" ❌ (Cyrillic)
	""")
}

/// Generates a masked string from a custom pattern.
///
/// This function interprets the pattern using the following rules:
/// - `A` → random uppercase Latin letter
/// - `X` → random digit
/// - any other character is preserved as-is
///
/// Example:
/// ```
/// "AA-XXXX" → "KF-2049"
/// ```
fileprivate func generateFromPattern(_ pattern: String) -> String {

	if containsCyrillic(pattern) {
		logCyrillicWarning(
			pattern: pattern,
			propertyName: nil
		)
	}

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

/// Generates a masked value for one of the built-in mask types.
///
/// This function is kept internal to the macro implementation
/// and is not exposed as part of the public API.
fileprivate func generateBuiltinMask(_ mask: BuiltinMask) -> String {
	switch mask {
	case .cardNumber:
		return generateFromPattern("XXXX XXXX XXXX XXXX")

	case .cardExpiry:
		return generateFromPattern("XX/XX")

	case .date:
		return generateFromPattern("XX-XX-XXXX")

	case .phoneUZ:
		let opCodes = ["90", "91", "93", "94", "95", "98", "99", "33", "88"]
		let code = opCodes.randomElement()!
		return "+998 \(code) " +
		"\(randomDigit())\(randomDigit())\(randomDigit()) " +
		"\(randomDigit())\(randomDigit()) " +
		"\(randomDigit())\(randomDigit())"

	case .pinflUZ:
		return (0..<14).map { _ in randomDigit() }.joined()

	case .passportUZ:
		return generateFromPattern("AAXXXXXXX")
	}
}

/// Compiler macro implementation for the `@Mask` attribute.
///
/// `MaskMacro` is a peer macro that inspects the `@Mask` attribute
/// applied to a stored property and generates a corresponding
/// masked value expression.
///
/// The macro does **not** generate random values itself.
/// Instead, it emits runtime calls to `MaskGenerator`,
/// ensuring that all randomness happens at runtime.
public struct MaskMacro: PeerMacro {

	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf decl: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {

		// Ensure the macro is applied to a stored property
		guard let varDecl = decl.as(VariableDeclSyntax.self) else { return [] }
		guard let name = varDecl.bindings.first?
			.pattern
			.as(IdentifierPatternSyntax.self)?
			.identifier.text
		else { return [] }

		var maskExpr: ExprSyntax?

		// MARK: - String-based pattern (legacy / internal)
		// Example: @Mask("AA-XXXX")
		if let stringLiteral = node.arguments?
			.as(LabeledExprListSyntax.self)?
			.first?
			.expression
			.as(StringLiteralExprSyntax.self),
		   let fullString = stringLiteral.representedLiteralValue
		{
			maskExpr = "MaskGenerator.fromPattern(\"\(raw: fullString)\")"
		}

		// MARK: - Built-in enum case
		// Example: @Mask(.cardNumber)
		if let enumArg = node.arguments?
			.as(LabeledExprListSyntax.self)?
			.first?
			.expression
			.as(MemberAccessExprSyntax.self)
		{
			let id = enumArg.declName.baseName.text
			if BuiltinMask(rawValue: id) != nil {
				maskExpr = "MaskGenerator.\(raw: id)()"
			}
		}

		// MARK: - Enum case with associated value
		// Example: @Mask(.pattern("AA-XXXX"))
		if let call = node.arguments?
			.as(LabeledExprListSyntax.self)?
			.first?
			.expression
			.as(FunctionCallExprSyntax.self),
		   let member = call.calledExpression.as(MemberAccessExprSyntax.self),
		   member.declName.baseName.text == "pattern",
		   let arg = call.arguments.first?
			.expression
			.as(StringLiteralExprSyntax.self),
		   let pattern = arg.representedLiteralValue
		{
			maskExpr = "MaskGenerator.fromPattern(\"\(raw: pattern)\")"
		}

		guard let maskValue = maskExpr else { return [] }

		// Generate a peer computed property `<propertyName>_masked`
		// This property is later consumed by `@Mockable`
		let peer: DeclSyntax =
		"""
		var \(raw: name)_masked: String {
			return \(raw: maskValue)
		}
		"""

		return [peer]
	}
}

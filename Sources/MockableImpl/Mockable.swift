//
//  Mockable.swift
//  MockableMacro
//
//  Created by Eli Safina on 09/10/25.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Type parsing helpers

/// Internal representation of a property type.
///
/// `TypeShape` is used to analyze property declarations
/// and decide how to generate a mock value for each type.
fileprivate indirect enum TypeShape {
	case simple(name: String)
	case optional(wrapped: TypeShape)
	case array(elem: TypeShape)
	case set(elem: TypeShape)
	case dictionary(key: TypeShape, value: TypeShape)
}

/// Trims whitespace and newlines from a type string.
fileprivate func trimSpaces(_ s: String) -> String {
	s.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Parses a Swift type string into a structured `TypeShape`.
///
/// Supported forms:
/// - Optional: `T?`, `Optional<T>`
/// - Array: `[T]`, `Array<T>`
/// - Set: `Set<T>`
/// - Dictionary: `[K: V]`, `Dictionary<K, V>`
fileprivate func parseType(_ type: String) -> TypeShape {
	let t = trimSpaces(type)

	if t.hasSuffix("?") {
		return .optional(wrapped: parseType(String(t.dropLast())))
	}
	if t.hasPrefix("Optional<"), t.hasSuffix(">") {
		return .optional(wrapped: parseType(String(t.dropFirst(9).dropLast())))
	}

	if t.hasPrefix("Array<"), t.hasSuffix(">") {
		return .array(elem: parseType(String(t.dropFirst(6).dropLast())))
	}
	if t.hasPrefix("["), t.hasSuffix("]"), !t.contains(":") {
		return .array(elem: parseType(String(t.dropFirst().dropLast())))
	}

	if t.hasPrefix("Set<"), t.hasSuffix(">") {
		return .set(elem: parseType(String(t.dropFirst(4).dropLast())))
	}

	if t.hasPrefix("Dictionary<"), t.hasSuffix(">") {
		let inner = String(t.dropFirst(11).dropLast())
		if let comma = inner.firstIndex(of: ",") {
			return .dictionary(
				key: parseType(String(inner[..<comma])),
				value: parseType(String(inner[inner.index(after: comma)...]))
			)
		}
	}

	if t.hasPrefix("["), t.hasSuffix("]"), t.contains(":") {
		let inner = String(t.dropFirst().dropLast())
		if let colon = inner.firstIndex(of: ":") {
			return .dictionary(
				key: parseType(String(inner[..<colon])),
				value: parseType(String(inner[inner.index(after: colon)...]))
			)
		}
	}

	return .simple(name: t)
}

// MARK: - Type classification

/// Built-in scalar types that receive primitive mock values.
///
/// Any other capitalized type name is treated as a user-defined model
/// and is expected to implement `static mock(...)`.
fileprivate let builtinScalars: Set<String> = [
	"String", "Substring",
	"Int", "Int8", "Int16", "Int32", "Int64",
	"UInt", "UInt8", "UInt16", "UInt32", "UInt64",
	"Float", "Double", "CGFloat", "Decimal",
	"Bool", "UUID", "Date", "URL", "Data"
]

/// Determines whether a type is considered a mockable user model.
fileprivate func isMockableModel(_ name: String) -> Bool {
	!builtinScalars.contains(name) && (name.first?.isUppercase ?? false)
}

// MARK: - Default value generation (deterministic)

/// Generates a mock value expression for a given property type.
///
/// ⚠️ This function is **deterministic** by design:
/// the same `index` always produces the same values.
/// Randomness is intentionally avoided here.
fileprivate func valueExpr(for shape: TypeShape, prop: String) -> ExprSyntax {
	switch shape {

	case .simple(let name):
		switch name {
		case "String", "Substring":
			return "\"\(raw: prop.capitalized)_\\(index)\""

		case "Int", "Int8", "Int16", "Int32", "Int64",
			 "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
			return "index * 3"

		case "Float", "Double", "CGFloat", "Decimal":
			return "Double(index)"

		case "Bool":
			return "(index % 2 == 0)"

		case "UUID":
			return "UUID()"

		case "Date":
			return "Date().addingTimeInterval(Double(index) * 1000)"

		case "URL":
			return "URL(string: \"https://example.com/\(raw: prop)/\\(index)\")!"

		case "Data":
			return "Data()"

		default:
			if isMockableModel(name) {
				return "\(raw: name).mock(index: index)"
			} else {
				return "\(raw: name)()"
			}
		}

	case .optional:
		return "nil"

	case .array(let elem):
		if case .simple(let name) = elem, isMockableModel(name) {
			return "\(raw: name).mockArray(2)"
		}
		let e = valueExpr(for: elem, prop: prop)
		return "[\(e), \(e)]"

	case .set(let elem):
		if case .simple(let name) = elem, isMockableModel(name) {
			return "Set(\(raw: name).mockArray(2))"
		}
		let e = valueExpr(for: elem, prop: prop)
		return "Set([\(e), \(e)])"

	case .dictionary(let key, let value):
		let k = valueExpr(for: key, prop: prop)
		let v = valueExpr(for: value, prop: prop)
		return "[\(k): \(v)]"
	}
}

// MARK: - Property extraction

/// Extracts stored (non-static) properties from a type declaration.
///
/// Computed properties and static members are ignored.
fileprivate func storedProperties(
	from decl: some DeclGroupSyntax
) -> [(varDecl: VariableDeclSyntax, name: String, shape: TypeShape)] {

	decl.memberBlock.members.compactMap { member in
		guard
			let varDecl = member.decl.as(VariableDeclSyntax.self),
			varDecl.bindings.count == 1,
			let binding = varDecl.bindings.first,
			let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
			let typeAnn = binding.typeAnnotation
		else { return nil }

		if varDecl.modifiers.contains(where: {
			if case .keyword(let kw) = $0.name.tokenKind {
				return kw == .static
			}
			return false
		}) { return nil }

		if binding.accessorBlock != nil { return nil }

		let name = pattern.identifier.text
		let shape = parseType(typeAnn.type.trimmedDescription)

		return (varDecl, name, shape)
	}
}

// MARK: - Mask integration

/// Resolves a `@Mask` attribute into a runtime mask generator expression.
///
/// This function bridges `@Mask` and `MaskGenerator`.
fileprivate func maskExpr(from varDecl: VariableDeclSyntax) -> String? {
	guard
		let attr = varDecl.attributes.first(where: {
			$0.as(AttributeSyntax.self)?
				.attributeName.trimmedDescription == "Mask"
		})?.as(AttributeSyntax.self),
		let args = attr.arguments?.as(LabeledExprListSyntax.self),
		let first = args.first
	else { return nil }

	let expr = first.expression

	// @Mask(.cardNumber)
	if let member = expr.as(MemberAccessExprSyntax.self) {
		return "MaskGenerator.\(member.declName.baseName.text)()"
	}

	// @Mask(.pattern("AAAA"))
	if let call = expr.as(FunctionCallExprSyntax.self),
	   let member = call.calledExpression.as(MemberAccessExprSyntax.self),
	   member.declName.baseName.text == "pattern",
	   let arg = call.arguments.first?.expression
			.as(StringLiteralExprSyntax.self)?
			.representedLiteralValue {
		return "MaskGenerator.fromPattern(\"\(arg)\")"
	}

	return nil
}

// MARK: - Macro implementation

/// Main implementation of the `@Mockable` macro.
///
/// Generates:
/// - `init(_mockIndex:)`
/// - `static mock()`
/// - `static mockArray()`
public struct MockableMacro: MemberMacro {

	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf decl: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {

		// MARK: - Enum support------------->
		if let enumDecl = decl.as(EnumDeclSyntax.self) {

			// Проверяем, что enum поддерживаемый
			// (без associated values)
			let cases = enumDecl.memberBlock.members.compactMap {
				$0.decl.as(EnumCaseDeclSyntax.self)
			}

			guard !cases.isEmpty else {
				return []
			}

			let isPublic = decl.modifiers.contains {
				if case .keyword(let kw) = $0.name.tokenKind {
					return kw == .public || kw == .open
				}
				return false
			}

			let access = isPublic ? "public " : ""

			let initDecl: DeclSyntax =
			"""
			\(raw: access)init(_mockIndex index: Int = 0) {
				let all = Self.allCases
				self = all[index % all.count]
			}
			"""

			let mockFunc: DeclSyntax =
			"""
			\(raw: access)static func mock(index: Int = 0) -> Self {
				.init(_mockIndex: index)
			}
			"""

			let mockArrayFunc: DeclSyntax =
			"""
			\(raw: access)static func mockArray(_ count: Int) -> [Self] {
				(0..<count).map { i in
					Self.mock(index: i)
				}
			}
			"""

			return [initDecl, mockFunc, mockArrayFunc]
		}
		// MARK: - Enum support<-------------

		let props = storedProperties(from: decl)
			.filter { !$0.name.hasSuffix("_masked") }

		let isPublic = decl.modifiers.contains {
			if case .keyword(let kw) = $0.name.tokenKind {
				return kw == .public || kw == .open
			}
			return false
		}

		let access = isPublic ? "public " : ""

		let assigns: [String] = props.map { varDecl, name, shape in
			if let maskExpr = maskExpr(from: varDecl) {
				return "self.\(name) = \(maskExpr)"
			} else {
				let expr = valueExpr(for: shape, prop: name).description
				return "self.\(name) = \(expr)"
			}
		}

		let initDecl: DeclSyntax =
		"""
		\(raw: access)init(_mockIndex index: Int = 1) {
			\(raw: assigns.joined(separator: "\n    "))
		}
		"""

		let mockFunc: DeclSyntax =
		"""
		\(raw: access)static func mock(index: Int = 1) -> Self {
			.init(_mockIndex: index)
		}
		"""

		let mockArrayFunc: DeclSyntax =
		"""
		\(raw: access)static func mockArray(_ count: Int) -> [Self] {
			(0..<count).map { i in
				Self.mock(index: i + 1)
			}
		}
		"""

		return [initDecl, mockFunc, mockArrayFunc]
	}
}

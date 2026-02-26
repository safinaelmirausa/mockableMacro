//
//  MockableClient.swift
//  MockableMacro
//
//  Created by Eli Safina on 09/10/25.
//
//  This file defines the public client-facing interface for the `@Mockable` macro.
//  The macro generates helper initializers and factory methods that produce
//  mock (fake) data for testing, previews, and demo purposes.
//
//  Example:
//      @Mockable
//      struct User {
//          var name: String
//          var age: Int
//      }
//
//      let mock = User.mock()
//      let list = User.mockArray(5)
//

import Foundation

/// Automatically generates mock data for structs and classes.
///
/// When the `@Mockable` attribute is applied to a type,
/// the macro generates the following members:
///
/// - `init(_mockIndex:)` – An initializer that assigns mock values
///   to all stored properties.
/// - `static func mock(index:)` – Creates a single mock instance.
/// - `static func mockArray(_:)` – Creates an array of mock instances.
///
/// The generated values are deterministic with respect to the `index` parameter,
/// which makes the output predictable and suitable for tests.
///
/// ## Supported property types
/// - Scalar types: `String`, `Int`, `Bool`, `Double`, `UUID`, `Date`, `URL`, `Data`
/// - Collections: `Array`, `Set`, `Dictionary`
/// - Nested models that also conform to `@Mockable`
///
/// Properties annotated with `@Mask` will use the corresponding
/// masking logic instead of default value generation.
///
/// ## Example
/// ```swift
/// @Mockable
/// struct Car {
///     var id: Int
///     var brand: String
/// }
///
/// let single = Car.mock()
/// let many = Car.mockArray(5)
/// ```
///
/// ## Using masks
/// Properties annotated with `@Mask` will use masking rules
/// instead of default mock value generation.
///
/// This allows you to generate fake but format-valid data
/// such as card numbers, phone numbers, or custom patterns.
///
/// ```swift
/// @Mockable
/// struct PaymentCard {
///     @Mask(.cardNumber)
///     var number: String
///
///     @Mask(.cardExpiry)
///     var expiry: String
///
///     @Mask(.pattern("AAA XX"))
///     var code: String
/// }
///
/// let card = PaymentCard.mock()
/// ```
///
/// Masked properties are initialized automatically during
/// mock creation and fully integrated with `@Mockable`.

/// - Note: The macro implementation lives in the `MockableImpl` module
///   and is connected via a Swift compiler plugin.
@attached(member, names: arbitrary)
public macro Mockable() = #externalMacro(
	module: "MockableImpl",
	type: "MockableMacro"
)

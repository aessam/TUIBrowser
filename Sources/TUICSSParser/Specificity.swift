// TUICSSParser - CSS Specificity

/// Represents CSS selector specificity for cascade resolution
/// Specificity is calculated as (a, b, c) where:
/// - a: count of ID selectors
/// - b: count of class selectors, attribute selectors, and pseudo-classes
/// - c: count of type selectors and pseudo-elements
public struct Specificity: Equatable, Comparable, Hashable, Sendable {
    /// Count of ID selectors (#id)
    public let a: Int

    /// Count of class selectors (.class), attribute selectors, pseudo-classes
    public let b: Int

    /// Count of type selectors (div, p) and pseudo-elements
    public let c: Int

    public init(a: Int, b: Int, c: Int) {
        self.a = a
        self.b = b
        self.c = c
    }

    /// Zero specificity (for universal selector *)
    public static let zero = Specificity(a: 0, b: 0, c: 0)

    /// Compare specificities
    /// Higher specificity wins in the cascade
    public static func < (lhs: Specificity, rhs: Specificity) -> Bool {
        if lhs.a != rhs.a {
            return lhs.a < rhs.a
        }
        if lhs.b != rhs.b {
            return lhs.b < rhs.b
        }
        return lhs.c < rhs.c
    }

    /// Add two specificities together
    public static func + (lhs: Specificity, rhs: Specificity) -> Specificity {
        Specificity(
            a: lhs.a + rhs.a,
            b: lhs.b + rhs.b,
            c: lhs.c + rhs.c
        )
    }
}

extension Specificity: CustomStringConvertible {
    public var description: String {
        "(\(a),\(b),\(c))"
    }
}

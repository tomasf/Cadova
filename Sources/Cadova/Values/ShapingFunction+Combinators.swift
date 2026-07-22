import Foundation

public extension ShapingFunction {
    /// Constructs a new shaping function that blends this function with another.
    ///
    /// The resulting function applies a weighted mix between `self` and `other`.
    /// When `weight` is 0.0, the result is identical to `self`. When `weight` is 1.0, the
    /// result is identical to `other`. Intermediate weights produce a linear interpolation
    /// between the two functions' outputs.
    ///
    /// This is useful when you want to gradually transition between two shaping behaviors.
    ///
    /// - Parameters:
    ///   - other: The shaping function to blend with.
    ///   - weight: A value between 0.0 and 1.0 indicating how much of `other` to include.
    /// - Returns: A new shaping function representing the blend.
    /// - Precondition: `weight` must be between 0.0 and 1.0, inclusive.
    ///
    func mixed(with other: ShapingFunction, weight: Double) -> Self {
        precondition(weight >= 0 && weight <= 1)
        return ShapingFunction(curve: .mix(self, other, weight))
    }

    /// Returns an inverted version of this shaping function.
    ///
    /// The inverted function is reflected about the point (0.5, 0.5), computed as `g(t) = 1 - f(1 - t)`.
    /// This swaps the behavior at the start and end of the curve:
    /// - Ease-in becomes ease-out
    /// - Ease-out becomes ease-in
    /// - Linear and symmetric functions (like `sine`) remain unchanged
    ///
    /// ```swift
    /// let easeOut = ShapingFunction.easeIn.inverted  // Equivalent to .easeOut
    /// ```
    ///
    var inverted: Self {
        ShapingFunction(curve: .inverted(self))
    }

    /// Returns a mirrored version of this shaping function.
    ///
    /// The mirrored function is geometrically reflected across the line y = x,
    /// computed as the inverse function `g(t) = f⁻¹(t)`. This produces true visual
    /// symmetry when the original and mirrored curves are plotted together.
    ///
    /// - Ease-in (below diagonal) becomes a curve above the diagonal
    /// - Ease-out (above diagonal) becomes a curve below the diagonal
    /// - Linear remains unchanged
    ///
    /// The inverse is computed numerically using binary search, which works for
    /// any monotonic shaping function.
    ///
    /// ```swift
    /// let reflected = ShapingFunction.easeIn.mirrored  // Visually symmetric across y = x
    /// ```
    ///
    var mirrored: Self {
        ShapingFunction(curve: .mirrored(self))
    }
}

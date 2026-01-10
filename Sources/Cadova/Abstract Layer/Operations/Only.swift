import Foundation

/// Result element that captures the build result from an `only()` modifier.
///
/// When present, the captured result should be used instead of the normal build result,
/// allowing isolation of a specific part of the geometry tree for debugging.
internal struct OnlyResult<D: Dimensionality>: ResultElement {
    let capturedResult: D.BuildResult?

    init() {
        self.capturedResult = nil
    }

    init(_ capturedResult: D.BuildResult) {
        self.capturedResult = capturedResult
    }

    init(combining elements: [OnlyResult<D>]) {
        let nonNil = elements.compactMap(\.capturedResult)
        // Allow duplicates if they're the same result (e.g., from sliced geometry operations)
        let uniqueNodes = Set(nonNil.map(\.node))
        precondition(uniqueNodes.count <= 1, "Multiple only() modifiers found in geometry tree - only one is allowed")
        self.capturedResult = nonNil.first
    }
}

/// A geometry wrapper that marks its content as the only geometry to be included in the output.
private struct OnlyMarker<D: Dimensionality>: Geometry {
    let body: D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let result = try await context.buildResult(for: body, in: environment.withOperation(.addition))

        // Return empty geometry to parent, but carry the captured result
        return D.BuildResult(element: OnlyResult(result))
    }
}

public extension Geometry {
    /// Marks this geometry as the only content to include in the model output.
    ///
    /// Use this modifier during development to isolate and preview a specific part of a
    /// complex geometry tree. When `only()` is applied, all other geometry in the model
    /// is excluded, and only the marked geometry (with its local coordinate system) is output.
    ///
    /// - Important: Only one `only()` modifier can be active in a geometry tree. Using multiple
    ///   will log an error and use the last one encountered.
    ///
    /// - Warning: This modifier is intended for debugging only.
    ///
    /// ## Example
    /// ```swift
    /// Box(100)
    ///     .subtracting {
    ///         Cylinder(diameter: 20, height: 50)
    ///             .only()  // Preview just the cylinder
    ///             .translated(z: 25)
    ///     }
    /// ```
    ///
    func only() -> D.Geometry {
        OnlyMarker(body: self)
    }
}

internal extension BuildResult {
    /// Returns the captured result from an `only()` modifier if present, otherwise returns self.
    ///
    /// The `OnlyResult` element is preserved in the returned result, so `hasOnly` remains accurate.
    var resolvingOnly: Self {
        guard let captured = elements[OnlyResult<D>.self].capturedResult else { return self }
        // Preserve the OnlyResult element so hasOnly still works after resolution
        return captured.replacing(elements: captured.elements.setting(elements[OnlyResult<D>.self]))
    }

    /// Whether an `only()` modifier was used somewhere in the geometry tree.
    var hasOnly: Bool {
        elements[OnlyResult<D>.self].capturedResult != nil
    }
}

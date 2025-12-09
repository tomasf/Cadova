import Foundation

struct ResultModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let modifier: @Sendable (ResultElements) -> ResultElements

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        return bodyResult.replacing(elements: modifier(bodyResult.elements))
    }
}

struct ResultAndGeometryModifier<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let modifier: @Sendable (ResultElements) -> (D.Geometry, ResultElements)

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let (newBody, elements) = modifier(bodyResult.elements)
        let newBodyResult = try await context.buildResult(for: newBody, in: environment)
        return newBodyResult.replacing(elements: elements)
    }
}

public extension Geometry {
    /// Attaches or replaces a typed result element on the build result of this geometry.
    ///
    /// Result elements are typed metadata produced during a build. This method returns a geometry
    /// that produces the same primary output as `self`, but with the given element set on the result.
    /// If an element of the same type already exists, it is replaced.
    ///
    /// - Parameter value: The `ResultElement` value to store.
    /// - Returns: A geometry that carries the provided result element.
    func withResult<E: ResultElement>(_ value: E) -> D.Geometry {
        ResultModifier(body: self) { elements in
            elements.setting(value)
        }
    }

    /// Updates a typed result element on the build result of this geometry.
    ///
    /// If the element is present, it is mutated in place; otherwise a default instance is created,
    /// mutated, and stored. The returned geometry produces the same primary output as `self`,
    /// but with the updated element attached to the result.
    ///
    /// - Parameters:
    ///   - type: The `ResultElement` type to modify.
    ///   - modifier: A closure that can mutate the element in place.
    /// - Returns: A geometry that carries the modified result element.
    func modifyingResult<E: ResultElement>(
        _ type: E.Type,
        modifier: @Sendable @escaping (inout E) -> Void
    ) -> D.Geometry {
        ResultModifier(body: self) { elements in
            var element = elements[E.self]
            modifier(&element)
            return elements.setting(element)
        }
    }
}

internal extension Geometry {
    func mergingResultElements(with otherElements: ResultElements) -> D.Geometry {
        ResultModifier(body: self) { elements in
            ResultElements(combining: [elements, otherElements])
        }
    }

    func modifyingResult<E: ResultElement>(
        _ type: E.Type,
        @GeometryBuilder<D3> modifier: @Sendable @escaping (D.Geometry, inout E) -> D.Geometry
    ) -> D.Geometry {
        ResultAndGeometryModifier(body: self) { elements in
            var element = elements[E.self]
            let geometry = modifier(self, &element)
            return (geometry, elements.setting(element))
        }
    }
}

import Foundation
import Manifold3D

/// The result of building a ``Geometry`` value: a geometry node plus any attached result elements.
///
/// This type is public only because it appears in the signature of `Geometry`'s `_build(in:context:)`
/// requirement, which every conforming type must satisfy. It isn't meant to be constructed, inspected,
/// or otherwise used directly — hence the underscore prefix.
public struct _BuildResult<D: Dimensionality>: Sendable {
    internal let node: D.Node
    internal let elements: ResultElements

    internal init(node: D.Node, elements: ResultElements) {
        self.node = node
        self.elements = elements
    }

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    internal init(combining results: [Self], operationType: BooleanOperationType) {
        self.node = .boolean(results.map { $0.node }, type: operationType)
        self.elements = .init(combining: results.map { $0.elements })
    }

    internal init(_ node: D.Node) {
        self.init(node: node, elements: [:])
    }

    internal init<Key: CacheKey>(cacheKey key: Key, elements: ResultElements) {
        self.init(node: .materialized(cacheKey: OpaqueKey(key)), elements: elements)
    }

    internal init<E: ResultElement>(_ node: D.Node = .empty, element: E) {
        self.init(node: node, elements: [ObjectIdentifier(E.self): element])
    }
}

/// Internal-facing name for ``_BuildResult``, used everywhere except public API signatures,
/// which are required to spell out the underscore-prefixed name.
internal typealias BuildResult<D: Dimensionality> = _BuildResult<D>

internal extension BuildResult {
    func replacing<New: Dimensionality>(node: New.Node) -> New.BuildResult {
        .init(node: node, elements: elements)
    }

    func replacing(elements: ResultElements) -> Self {
        .init(node: node, elements: elements)
    }

    func modifyingNode<New: Dimensionality>(_ modifier: (D.Node) -> New.Node) -> New.BuildResult {
        .init(node: modifier(node), elements: elements)
    }

    func modifyingElement<E: ResultElement>(_ type: E.Type, _ modifier: (inout E) -> Void) -> Self {
        var element = elements[E.self]
        modifier(&element)
        return replacing(elements: elements.setting(element))
    }

    func modifyingElement<E: ResultElement>(_ type: E.Type, _ modifier: (E) async throws -> E) async rethrows -> Self {
        replacing(elements: elements.setting(try await modifier(elements[E.self])))
    }

    func mergingElements(_ newElements: ResultElements) -> Self {
        .init(node: node, elements: .init(combining: [newElements, elements]))
    }

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func applyingTransform(_ transform: D.Transform) -> Self {
        let newNode = GeometryNode<D>.transform(node, transform: transform)
        let newElements = elements.setting(elements[PartCatalog.self].applyingTransform(transform.transform3D))
        return Self(node: newNode, elements: newElements)
    }
}

internal extension BuildResult {
    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    init(
        booleanOperation: BooleanOperationType,
        geometries: [D.Geometry],
        environment: EnvironmentValues,
        context: EvaluationContext
    ) async throws {
        let childResults = try await geometries.asyncMap {
            try await context.buildResult(for: $0, in: environment)
        }

        guard childResults.contains(where: {
            $0.elements[ifPresent: ReferenceState.self]?.hasUsedReferences == true
        }) else {
            self = .init(combining: childResults, operationType: booleanOperation)
            return
        }

        let newChildResults = try await childResults.enumerated().asyncMap { index, childResult in
            guard
                let referenceState = childResult.elements[ifPresent: ReferenceState.self],
                referenceState.hasUsedReferences
            else { return childResult }


            let otherChildren = childResults.enumerated().filter { $0.offset != index }.map(\.element)
            let otherReferenceStates = otherChildren.compactMap { $0.elements[ifPresent: ReferenceState.self]}
            let combinedReferenceState = ReferenceState(combining: otherReferenceStates)

            guard combinedReferenceState.definesReferences(usedIn: referenceState) else {
                return childResult
            }

            // Re-evaluate geometry with newly found references
            let newEnvironment = environment.withDefinedReferences(combinedReferenceState)
            return try await context.buildResult(for: geometries[index], in: newEnvironment)
        }

        self = .init(combining: newChildResults, operationType: booleanOperation)
    }

}

internal extension BuildResult<D2> {
    func promotedTo3D() -> BuildResult<D3> {
        replacing(node: .extrusion(node, type: .linear(height: 0.001)))
    }
}

extension _BuildResult: Geometry {
    public func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> D._BuildResult {
        self
    }
}

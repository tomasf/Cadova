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
        self.init(node: .materialized(cacheKey: AnyCacheKey(key)), elements: elements)
    }

    internal init<E: ResultElement>(_ node: D.Node = .empty, element: E) {
        self.init(node: node, elements: [ObjectIdentifier(E.self): element])
    }
}

/// Internal-facing name for ``_BuildResult``, used everywhere except public API signatures,
/// which are required to spell out the underscore-prefixed name.
internal typealias BuildResult<D: Dimensionality> = _BuildResult<D>

internal extension BuildResult {
    func replacing<New: Dimensionality>(node: New.Node) -> BuildResult<New> {
        .init(node: node, elements: elements)
    }

    func replacing(elements: ResultElements) -> Self {
        .init(node: node, elements: elements)
    }

    func modifyingNode<New: Dimensionality>(_ modifier: (D.Node) -> New.Node) -> BuildResult<New> {
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
    public func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> _BuildResult<D> {
        self
    }
}

/// A geometry that stands in for another one whose build has already been performed.
///
/// Reader operations — `measuring`, `separated`, `readingConcrete`, `evaluating` — have to build
/// their target before they can hand anything to their closure. Handing the *source* geometry back
/// to that closure makes the closure's result build the same subtree all over again, so nesting `k`
/// readers walks the base `2^k` times. Handing back the finished `BuildResult` avoids the rebuild,
/// but freezes the build: `BuildResult` builds to itself, so an environment modifier applied inside
/// the closure would silently do nothing.
///
/// This type does both. It replays the finished build when it is asked to build under the very same
/// environment and evaluation context that produced it, and falls back to a real build of `source`
/// under anything else — which is exactly the case where a builder closure legitimately wraps the
/// geometry it was handed in an environment modifier.
///
/// The environment half of the key is exact rather than approximate: ``EnvironmentValues/id`` is
/// regenerated on every mutation, so an unchanged `id` means an unchanged environment. The context
/// half matters because a `BuildResult` isn't portable between contexts — a `.materialized` node
/// only resolves in the context whose cache the generator was declared on.
internal struct PrebuiltGeometry<D: Dimensionality>: Geometry {
    let source: D.Geometry
    let environmentID: UUID
    let contextToken: GeometryCache<D2>
    let result: BuildResult<D>

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        guard environment.id == environmentID, context.identityToken === contextToken else {
            return try await context.buildResult(for: source, in: environment)
        }
        return result
    }
}

internal extension BuildResult {
    /// A geometry that replays this build when asked for it under `environment` in `context`, and
    /// builds `source` from scratch under anything else.
    func standingIn(for source: D.Geometry, in environment: EnvironmentValues, context: EvaluationContext) -> D.Geometry {
        PrebuiltGeometry(
            source: source, environmentID: environment.id, contextToken: context.identityToken, result: self
        )
    }
}

import Foundation
import Manifold3D

public struct BuildResult<D: Dimensionality>: Sendable {
    internal let node: D.Node
    internal let elements: ResultElements

    internal init(node: D.Node, elements: ResultElements) {
        self.node = node
        self.elements = elements
    }

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
}

internal extension BuildResult {
    func replacing<New: Dimensionality>(node: New.Node) -> New.BuildResult {
        .init(node: node, elements: elements)
    }

    func replacing<New: Dimensionality, Key: CacheKey>(cacheKey: Key) -> New.BuildResult {
        .init(node: .materialized(cacheKey: OpaqueKey(cacheKey)), elements: elements)
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

    func modifyingElement<E: ResultElement>(_ type: E.Type, _ modifier: (E) -> E) -> Self {
        replacing(elements: elements.setting(modifier(elements[E.self])))
    }

    func modifyingElement<E: ResultElement>(_ type: E.Type, _ modifier: (E) async throws -> E) async rethrows -> Self {
        replacing(elements: elements.setting(try await modifier(elements[E.self])))
    }

    func applyingTransform(_ transform: D.Transform) -> Self {
        let newNode = GeometryNode<D>.transform(node, transform: transform)
        let newElements = elements.setting(elements[PartCatalog.self].applyingTransform(transform.transform3D))
        return Self(node: newNode, elements: newElements)
    }
}

extension BuildResult: Geometry {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        self
    }
}

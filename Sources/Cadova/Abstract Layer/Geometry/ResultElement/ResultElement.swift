import Foundation

/// A typed, mergeable piece of build metadata, traveling alongside the actual geometry
/// output.
///
/// Result elements let you attach auxiliary information to the result of building
/// a geometry. They propagate through the pipeline together with the geometry’s
/// node representation.
///
/// Conforming types must be `Sendable`, and provide:
/// - A default initializer used when a value of this type is requested but not present.
/// - A combining initializer to resolve multiple values of the same type (e.g., when
///   merging results from multiple children).
///
/// Typical usage:
/// - Use helpers like `withResult(_:)` and `modifyingResult(_:modifier:)` to set or update
///   elements on a geometry.
/// - When multiple values are merged, elements of the same type are combined using
///   `init(combining:)`.
///
public protocol ResultElement: Sendable {
    /// Creates a default value for this element type.
    ///
    /// Called when a build result does not contain a value of this type but one is requested.
    init()

    /// Creates a value by combining multiple instances of the same element type.
    ///
    /// This is used when multiple build results are merged and more than one value of this type
    /// is present. Implementations should define a stable, deterministic merge policy
    /// (such as last-wins, union, intersection, or accumulation) appropriate to the element’s meaning.
    ///
    /// - Parameter combining: The instances to be combined.
    init(combining: [Self])
}

internal extension ResultElement {
    static func combine(anyElements elements: [any ResultElement]) -> Self? {
        Self(combining: elements as! [Self])
    }
}

internal typealias ResultElements = [ObjectIdentifier: any ResultElement]

internal extension ResultElements {
    init(combining elements: [Self]) {
        self = elements.reduce(into: [ObjectIdentifier: [any ResultElement]]()) {
            for (key, value) in $1 {
                $0[key, default: []].append(value)
            }
        }
        .compactMapValues {
            $0.count > 1 ? type(of: $0[0]).combine(anyElements: $0) : $0[0]
        }
    }

    subscript<E: ResultElement>(_ type: E.Type) -> E {
        get {
            if let match = self[ObjectIdentifier(type)] {
                return match as! E
            } else {
                return E()
            }
        }
        set { self[ObjectIdentifier(type)] = newValue }
    }

    subscript<E: ResultElement>(ifPresent type: E.Type) -> E? {
        get {
            self[ObjectIdentifier(type)] as! E?
        }
    }

    func setting<E: ResultElement>(_ value: E) -> Self {
        var dict = self
        dict[E.self] = value
        return dict
    }
}

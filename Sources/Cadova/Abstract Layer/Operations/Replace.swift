import Foundation

public extension Geometry {
    func replaced(
        if condition: Bool,
        @GeometryBuilder<D> with replacement: @Sendable @escaping (_ input: D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        if condition {
            replacement(self)
        } else {
            self
        }
    }

    func replaced<T: Sendable>(
        if optional: T?,
        @GeometryBuilder<D> with replacement: @Sendable @escaping (_ input: D.Geometry, _ value: T) -> D.Geometry
    ) -> D.Geometry {
        if let optional {
            replacement(self, optional)
        } else {
            self
        }
    }

    func replaced<Output: Dimensionality>(
        @GeometryBuilder<Output> with replacement: @Sendable @escaping (_ input: D.Geometry) -> Output.Geometry
    ) -> Output.Geometry {
        replacement(self)
    }
}

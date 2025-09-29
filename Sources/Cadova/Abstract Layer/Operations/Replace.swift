import Foundation

public extension Geometry {
    func replaced(
        if condition: Bool,
        @GeometryBuilder<D> with replacement: @Sendable @escaping (_ input: D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        if condition {
            Deferred { replacement(self) }
        } else {
            self
        }
    }

    func replaced<T: Sendable>(
        if optional: T?,
        @GeometryBuilder<D> with replacement: @Sendable @escaping (_ input: D.Geometry, _ value: T) -> D.Geometry
    ) -> D.Geometry {
        if let optional {
            Deferred { replacement(self, optional) }
        } else {
            self
        }
    }

    func replaced<Output: Dimensionality>(
        @GeometryBuilder<Output> with replacement: @Sendable @escaping (_ input: D.Geometry) -> Output.Geometry
    ) -> Output.Geometry {
        Deferred { replacement(self) }
    }
}

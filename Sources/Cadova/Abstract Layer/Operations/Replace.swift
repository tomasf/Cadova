import Foundation

public extension Geometry {
    func replaced(
        if condition: Bool = true,
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
}

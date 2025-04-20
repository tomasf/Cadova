import Foundation

public extension Geometry {
    func replaced(if condition: Bool = true, @GeometryBuilder<D> with replacement: (_ input: D.Geometry) -> D.Geometry) -> D.Geometry {
        if condition {
            replacement(self)
        } else {
            self
        }
    }

    func replaced<T>(if optional: T?, @GeometryBuilder<D> with replacement: (_ input: D.Geometry, _ value: T) -> D.Geometry) -> D.Geometry {
        if let optional {
            replacement(self, optional)
        } else {
            self
        }
    }
}

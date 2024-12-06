import Foundation

public extension Geometry2D {
    func replaced(if condition: Bool = true, @GeometryBuilder2D with replacement: (_ input: any Geometry2D) -> any Geometry2D) -> any Geometry2D {
        if condition {
            replacement(self)
        } else {
            self
        }
    }

    func replaced<T>(if optional: T?, @GeometryBuilder2D with replacement: (_ input: any Geometry2D, _ value: T) -> any Geometry2D) -> any Geometry2D {
        if let optional {
            replacement(self, optional)
        } else {
            self
        }
    }
}

public extension Geometry3D {
    func replaced(if condition: Bool = true, @GeometryBuilder3D with replacement: (_ input: any Geometry3D) -> any Geometry3D) -> any Geometry3D {
        if condition {
            replacement(self)
        } else {
            self
        }
    }

    func replaced<T>(if optional: T?, @GeometryBuilder3D with replacement: (_ input: any Geometry3D, _ value: T) -> any Geometry3D) -> any Geometry3D {
        if let optional {
            replacement(self, optional)
        } else {
            self
        }
    }
}

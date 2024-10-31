import Foundation

/// A protocol defining the requirements for custom 3D shapes.
///
/// Conform to `Shape2D` to create custom types that represent 2D geometries. A conforming type must provide a `body` property, which defines the shape's geometry using geometry primitives and operations. The `Shape2D` protocol itself conforms to `Geometry2D`, ensuring that custom shapes can be used anywhere standard SwiftSCAD 2D geometries are used.
///
/// Example:
/// ```
/// struct CustomShape: Shape2D {
///     var body: some Geometry2D {
///         // Define the shape
///     }
/// }
/// ```
public protocol Shape2D: Geometry2D {
    /// The geometry content of this shape.
    ///
    /// Implement this property to define the shape's structure using SwiftSCAD's geometry primitives and operations.
    @GeometryBuilder2D var body: any Geometry2D { get }
}

public extension Shape2D {
    private func preparedBody(in environment: Environment) -> any Geometry2D {
        environment.inject(into: self)
        return body
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        preparedBody(in: environment).codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        preparedBody(in: environment).boundary(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        preparedBody(in: environment).elements(in: environment)
    }
}

/// A protocol defining the requirements for custom 3D shapes.
///
/// Conform to `Shape3D` to create custom types that represent 3D geometries. A conforming type must provide a `body` property, which defines the shape's geometry using geometry primitives and operations. The `Shape3D` protocol itself conforms to `Geometry3D`, ensuring that custom shapes can be used anywhere standard SwiftSCAD 3D geometries are used.
///
/// Example:
/// ```
/// struct CustomShape: Shape3D {
///     var body: some Geometry3D {
///         // Define the shape
///     }
/// }
/// ```
public protocol Shape3D: Geometry3D {
    /// The geometry content of this shape.
    ///
    /// Implement this property to define the shape's structure using SwiftSCAD's geometry primitives and operations.
    @GeometryBuilder3D var body: any Geometry3D { get }
}

public extension Shape3D {
    private func preparedBody(in environment: Environment) -> any Geometry3D {
        environment.inject(into: self)
        return body
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        preparedBody(in: environment).codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        preparedBody(in: environment).boundary(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        preparedBody(in: environment).elements(in: environment)
    }
}

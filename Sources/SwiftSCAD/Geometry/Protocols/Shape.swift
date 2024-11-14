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
    func evaluated(in environment: EnvironmentValues) -> Output {
        environment.whileCurrent {
            body.evaluated(in: environment)
        }
    }

    func inCurrentEnvironment(@GeometryBuilder2D _ contents: @escaping () -> any Geometry2D) -> any Geometry2D {
        readEnvironment { environment in
            environment.whileCurrent {
                contents()
            }
        }
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
    func evaluated(in environment: EnvironmentValues) -> Output {
        environment.whileCurrent {
            body.evaluated(in: environment)
        }
    }

    func inCurrentEnvironment(@GeometryBuilder3D _ contents: @escaping () -> any Geometry3D) -> any Geometry3D {
        readEnvironment { environment in
            environment.whileCurrent {
                contents()
            }
        }
    }
}

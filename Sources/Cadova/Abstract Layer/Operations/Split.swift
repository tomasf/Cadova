import Foundation
import Manifold3D

public extension Geometry3D {
    /// Splits the geometry into two parts along the specified plane.
    ///
    /// This method slices the geometry in two using a given plane and passes the resulting parts
    /// to a closure for further transformation or arrangement.
    ///
    /// - Parameters:
    ///   - plane: The `Plane` used to split the geometry.
    ///   - reader: A closure that receives the two resulting geometry parts (on opposite sides of the plane)
    ///             and returns a new composed geometry. The first geometry is the side facing the direction
    ///             of the plane's vector.
    ///
    /// - Returns: A new geometry resulting from the closure.
    ///
    /// ## Example
    /// ```swift
    /// Sphere(diameter: 5)
    ///     .split(along: Plane(z: 3)) { a, b in
    ///         a.colored(.red)
    ///         b.colored(.blue)
    ///     }
    /// ```
    ///
    func split(
        along plane: Plane,
        @GeometryBuilder3D reader: @Sendable @escaping (_ over: any Geometry3D, _ under: any Geometry3D) -> any Geometry3D
    ) -> any Geometry3D {
        CachedConcreteArrayTransformer(body: self, name: "Cadova.SplitAlongPlane", parameters: plane) { input in
            let (a, b) = input.translate(-plane.offset)
                .split(by: plane.normal.unitVector, originOffset: 0)
            return [a, b]
        } resultHandler: { geometries in
            precondition(geometries.count == 2, "Split result should contain exactly two geometries")
            return reader(
                geometries[0].translated(plane.offset),
                geometries[1].translated(plane.offset)
            )
        }
    }

    /// Splits the geometry into two parts along the specified plane and arranges them side-by-side.
    ///
    /// This variant is useful for preparing a model to be 3D printed in two halves. It aligns the split
    /// faces downward (or upward, if `flipped` is true), and places the parts next to each other along the chosen axis.
    ///
    /// - Parameters:
    ///   - plane: The `Plane` used to split the geometry.
    ///   - axis: The axis along which the two parts will be arranged.
    ///   - flipped: Whether to invert the default face-up orientation. Defaults to `false`.
    ///   - spacing: The distance between the arranged parts. Defaults to `3.0` mm.
    ///
    /// - Returns: A new geometry containing the arranged parts
    ///
    /// ## Example
    /// ```swift
    /// model.split(along: Plane(x: 10), arrangingPartsAlong: .y)
    ///
    func split(
        along plane: Plane,
        arrangingPartsAlong axis: Axis3D,
        flipped: Bool = false,
        spacing: Double = 3.0
    ) -> any Geometry3D {
        split(along: plane) { a, b in
            Stack(axis, spacing: spacing, alignment: .center, .minZ) {
                a.rotated(from: plane.normal, to: flipped ? .down : .up)
                b.rotated(from: plane.normal, to: flipped ? .up : .down)
            }
        }
    }

    /// Splits the geometry using a mask geometry and passes the results to a closure.
    ///
    /// This variant uses a mask volume to determine the split boundary. The result consists of the
    /// parts of the original geometry that are inside and outside the mask, respectively.
    ///
    /// - Parameters:
    ///   - mask: A closure that builds the mask geometry.
    ///   - result: A closure that receives the two resulting geometries (inside and outside the mask).
    ///
    /// - Returns: A new geometry composed from the parts returned by the `result` closure.
    ///
    /// ## Example
    /// ```swift
    /// model.split(with: { CuttingBlock() }) { inside, outside in
    ///     inside.colored(.green)
    ///     outside.colored(.gray)
    /// }
    /// ```
    func split(
        @GeometryBuilder3D with mask: @escaping () -> any Geometry3D,
        @GeometryBuilder3D result: @Sendable @escaping (_ inside: any Geometry3D, _ outside: any Geometry3D) -> any Geometry3D
    ) -> any Geometry3D {
        mask().readingConcrete { concrete, maskResult in
            CachedConcreteArrayTransformer(body: self, name: "Cadova.SplitWithMask", parameters: maskResult.node) { input in
                let (a, b) = input.split(by: concrete)
                return [a, b]
            } resultHandler: { geometries in
                precondition(geometries.count == 2, "Split result should contain exactly two geometries")

                return result(
                    geometries[0].mergingResultElements(with: maskResult.elements),
                    geometries[1].mergingResultElements(with: maskResult.elements)
                )
            }
        }
    }

    /// Trims the geometry along the specified plane, keeping only the portion facing the plane's normal direction.
    ///
    /// This method behaves like a one-sided split: it cuts the geometry by a plane and removes everything
    /// on the opposite side of the plane's vector. The result is the portion of the geometry that remains
    /// in the direction the plane is facing.
    ///
    /// - Parameter plane: The `Plane` defining the trimming boundary.
    /// - Returns: A new geometry containing only the portion of the original shape facing the plane's normal.
    ///
    /// ## Example
    /// ```swift
    /// Sphere(diameter: 5)
    ///     .trimmed(along: Plane(z: 0))
    /// ```
    ///
    func trimmed(along plane: Plane) -> any Geometry3D {
        GeometryNodeTransformer(body: self) { .trim($0, plane: plane) }
    }
}

public extension Geometry {
    /// Splits the geometry into its disconnected components and passes them to a reader closure.
    ///
    /// This method identifies and extracts all topologically disconnected parts of the geometry,
    /// such as individual shells or pieces that do not touch each other. The resulting components
    /// are passed to a closure, allowing you to process, rearrange, or visualize them as desired.
    ///
    /// - Parameter reader: A closure that takes the array of separated components and returns a new geometry.
    /// - Returns: A new geometry built from the components returned by the `reader` closure.
    ///
    /// ## Example
    /// ```swift
    /// model.separated { components in
    ///     Stack(.x, spacing: 1) {
    ///         for component in components {
    ///             component
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// In this example, each disconnected part of the model is extracted and displayed side-by-side
    /// along the X axis with a spacing of 1 mm.
    func separated(@GeometryBuilder<D> reader: @Sendable @escaping (_ components: [D.Geometry]) -> D.Geometry) -> D.Geometry {
        CachedConcreteArrayTransformer(body: self, name: "Cadova.Separate") {
            $0.decompose()
        } resultHandler: {
            reader($0)
        }
    }
}

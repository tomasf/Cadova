import Foundation
import Manifold3D

public extension Geometry3D {
    // Split the geometry into two parts along a specified plane, at a specified point

    func split(
        along plane: Plane,
        @GeometryBuilder3D reader: @escaping (any Geometry3D, any Geometry3D) -> any Geometry3D
    ) -> any Geometry3D {
        self
            .translated(-plane.offset)
            .readingPrimitive { input, _, elements in
                let (a, b) = input.split(by: plane.normal.unitVector, originOffset: 0)
                return reader(
                    a.geometry(with: elements).translated(plane.offset),
                    b.geometry(with: elements).translated(plane.offset)
                )
            }
    }

    // Split the geometry into two parts along a specified plane, at a specified point,
    // arranging them plane-side down next to each other. This is useful for 3D printing where
    // a part is split into two for easier printing

    func split(
        along plane: Plane,
        arrangingPartsAlong axis: Axis3D,
        spacing: Double = 3.0
    ) -> any Geometry3D {
        split(along: plane) { a, b in
            Stack(axis, spacing: spacing, alignment: .center, .minZ) {
                a.rotated(from: plane.normal, to: .up)
                b.rotated(from: plane.normal, to: .down)
            }
        }
    }
}

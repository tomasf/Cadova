import Foundation
import Manifold3D

// Don't make CacheKeys fileprivate; type demangling won't work
internal struct PlaneSplitParameters: CacheKey {
    let plane: Plane
}

internal struct MaskSplitParameters: CacheKey {
    let mask: GeometryExpression3D
}

public extension Geometry3D {
    // Split the geometry into two parts along a specified plane, at a specified point

    func split(
        along plane: Plane,
        @GeometryBuilder3D reader: @Sendable @escaping (any Geometry3D, any Geometry3D) -> any Geometry3D
    ) -> any Geometry3D {
        CachingPrimitiveArrayTransformer(body: self, key: PlaneSplitParameters(plane: plane)) { input in
            let (a, b) = input.split(by: plane.normal.unitVector, originOffset: 0)
            return [a, b]
        } resultHandler: { geometries in
            precondition(geometries.count == 2, "Split result should contain exactly two geometries")
            return reader(
                geometries[0].translated(plane.offset),
                geometries[1].translated(plane.offset)
            )
        }
    }

    // Split the geometry into two parts along a specified plane, at a specified point,
    // arranging them plane-side down next to each other. This is useful for 3D printing where
    // a part is split into two for easier printing

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

    func split(
        with mask: any Geometry3D,
        @GeometryBuilder3D reader: @Sendable @escaping (any Geometry3D, any Geometry3D) -> any Geometry3D
    ) -> any Geometry3D {
        mask.readingPrimitive { maskPrimitive, maskExpression in
            CachingPrimitiveArrayTransformer(body: self, key: MaskSplitParameters(mask: maskExpression)) { input in
                let (a, b) = input.split(by: maskPrimitive)
                return [a, b]
            } resultHandler: { geometries in
                precondition(geometries.count == 2, "Split result should contain exactly two geometries")
                return reader(geometries[0], geometries[1])
            }
        }
    }

    func split(
        @GeometryBuilder3D with mask: @escaping () -> any Geometry3D,
        @GeometryBuilder3D reader: @Sendable @escaping (any Geometry3D, any Geometry3D) -> any Geometry3D
    ) -> any Geometry3D {
        split(with: mask(), reader: reader)
    }
}

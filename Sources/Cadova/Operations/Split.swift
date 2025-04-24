import Foundation
import Manifold3D

// Don't make CacheKeys fileprivate; type demangling won't work
internal struct PlaneSplitPartParameters: CacheKey {
    let plane: Plane
    let isFirst: Bool
}

internal struct MaskSplitPartParameters: CacheKey {
    let mask: GeometryExpression3D
    let isFirst: Bool
}

public extension Geometry3D {
    // Split the geometry into two parts along a specified plane, at a specified point

    func split(
        along plane: Plane,
        @GeometryBuilder3D reader: @Sendable @escaping (any Geometry3D, any Geometry3D) -> any Geometry3D
    ) -> any Geometry3D {
        let keys = [
            PlaneSplitPartParameters(plane: plane, isFirst: true),
            PlaneSplitPartParameters(plane: plane, isFirst: false)
        ]

        return CachingPrimitiveArrayTransformer(body: self, keys: keys) { input in
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
            let keys = [
                MaskSplitPartParameters(mask: maskExpression, isFirst: true),
                MaskSplitPartParameters(mask: maskExpression, isFirst: false)
            ]

            return CachingPrimitiveArrayTransformer(body: self, keys: keys) { input in
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

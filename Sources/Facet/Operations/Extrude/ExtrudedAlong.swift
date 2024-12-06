import Foundation

public extension Geometry2D {
    /// Extrudes the two-dimensional shape along a specified bezier path.
    ///
    /// This method creates a 3D geometry by extruding the invoking 2D shape along a given bezier path. The extrusion follows the path's curvature, applying appropriate rotations to maintain the shape's orientation relative to the path's direction.
    ///
    /// If the path is closed, meaning its start and end points coincide, the extrusion connects the ends of the shape at the point of closure, forming a continuous loop without flat ends.
    ///
    /// - Parameters:
    ///  - path: A 2D or 3D `BezierPath` representing the path along which to extrude the shape.
    ///  - range: The position range to extrude. Defaults to nil, which extrudes the entire path.

    func extruded<V: Vector>(along path: BezierPath<V>, in range: ClosedRange<BezierPath.Position>? = nil) -> any Geometry3D {
        path.readPoints(in: range) { rawPoints in
            let points = rawPoints.map(\.vector3D)
            let isClosed = points[0].distance(to: points.last!) < 0.0001
            let rotations = ([.up] + points.paired().map { $1 - $0 })
                .paired().map(AffineTransform3D.rotation(from:to:))
                .cumulativeCombination { $0.concatenated(with: $1) }
            let lastRotation = rotations.last!
            let firstRotation = rotations.first!
            let closeRotation = AffineTransform3D.linearInterpolation(lastRotation, firstRotation, factor: 0.5)

            let clipRotations = [isClosed ? closeRotation : firstRotation] +
            rotations.paired().map {
                .linearInterpolation($0, $1, factor: 0.5)
            } + [isClosed ? closeRotation : lastRotation]

            let segments = points.paired().enumerated().map { i, p in
                Segment(
                    origin: p.0,
                    end: p.1,
                    originRotation: rotations[i],
                    originClipRotation: clipRotations[i],
                    endClipRotation: clipRotations[i + 1]
                )
            }

            let long = 1000.0
            for segment in segments {
                let distance = segment.origin.distance(to: segment.end)
                self.extruded(height: distance + long * 2)
                    .translated(z: -long)
                    .transformed(segment.originRotation)
                    .translated(segment.origin)
                    .intersecting {
                        Box(long)
                            .aligned(at: .centerXY)
                            .translated(z: -0.01)
                            .transformed(segment.originClipRotation)
                            .translated(segment.origin)
                    }
                    .intersecting {
                        Box(long)
                            .aligned(at: .centerXY, .maxZ)
                            .translated(z: 0.01)
                            .transformed(segment.endClipRotation)
                            .translated(segment.end)
                    }
            }
        }
    }
}

fileprivate struct Segment {
    let origin: Vector3D
    let end: Vector3D
    let originRotation: AffineTransform3D
    let originClipRotation: AffineTransform3D
    let endClipRotation: AffineTransform3D
}

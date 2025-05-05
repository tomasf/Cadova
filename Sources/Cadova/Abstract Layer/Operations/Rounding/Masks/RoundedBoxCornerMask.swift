import Foundation

internal struct RoundedBoxCornerMask: Shape3D {
    let boxSize: Vector3D
    let radius: Double

    @Environment(\.segmentation) var segmentation

    init(boxSize: Vector3D, radius: Double) {
        precondition(boxSize.allSatisfy { $0 >= radius }, "All box dimensions must be >= radius")
        self.boxSize = boxSize
        self.radius = radius
    }

    var body: any Geometry3D {
        Sphere(radius: radius)
            .intersecting {
                Box(radius)
                    .translated(x: -radius, y: -radius, z: -radius)
            }
            .translated(x: radius, y: radius, z: radius)
            .extended(to: boxSize)
    }
}

internal extension Geometry3D {
    func extended(to extent: Double, along axis: Axis3D) -> D3.Geometry {
        measureBoundsIfNonEmpty { body, e, bounds in
            let max = bounds.maximum[axis] - 1e-5
            if extent <= max {
                return body
            }
            let plane = Plane(perpendicularTo: axis, at: max)
            return body.adding {
                body.sliced(along: plane)
                    .extruded(height: extent - max)
                    .transformed(plane.transform)
            }
        }
    }

    func extended(to size: Vector3D) -> D3.Geometry {
        extended(to: size.x, along: .x)
        .extended(to: size.y, along: .y)
        .extended(to: size.z, along: .z)
    }
}

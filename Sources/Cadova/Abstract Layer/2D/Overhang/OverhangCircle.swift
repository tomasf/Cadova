import Foundation

internal struct OverhangCircle: Shape2D {
    let radius: Double

    @Environment(\.naturalUpDirectionXYAngle) private var upAngle
    @Environment(\.overhangAngle) private var overhangAngle
    @Environment(\.circularOverhangMethod) private var method
    @Environment(\.operation) private var operation

    var body: any Geometry2D {
        let circle = Circle(radius: radius)

        guard let upAngle else {
            return circle
        }

        let teardrop = circle.convexHull(adding: [0, radius / sin(overhangAngle)])
        let bridge = teardrop.intersecting(Rectangle(radius * 2).aligned(at: .center))

        let base = switch method {
        case .none: circle
        case .teardrop: teardrop
        case .bridge: bridge
        }

        return base.rotated(upAngle - (operation == .subtraction ? 90° : -90°))
    }
}

internal struct OverhangCylinder: Shape3D {
    let source: Cylinder

    var body: any Geometry3D {
        guard (source.topRadius > .ulpOfOne || source.bottomRadius > .ulpOfOne),
              source.height > .ulpOfOne else {
            return Empty()
        }

        return if source.bottomRadius < .ulpOfOne {
            OverhangCircle(radius: source.topRadius)
                .extruded(height: source.height, topScale: .zero)
                .flipped(along: .z)
                .translated(z: source.height)
        } else {
            OverhangCircle(radius: source.bottomRadius)
                .extruded(height: source.height, topScale: Vector2D(source.topRadius / source.bottomRadius))
        }
    }
}

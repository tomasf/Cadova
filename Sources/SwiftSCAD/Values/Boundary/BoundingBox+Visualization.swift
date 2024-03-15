import Foundation

extension BoundingBox {
    fileprivate var visualizationBorderColor: Color {
        Color.named(.blue, alpha: 1)
    }

    fileprivate var visualizationStandardBorderWidth: Double { 0.1 }
}

public extension BoundingBox2D {
    @UnionBuilder2D
    func visualized(scale: Double = 1.0) -> any Geometry2D {
        let borderWidth = visualizationStandardBorderWidth * scale
        let half = Union {
            Rectangle([maximum.x - minimum.x, borderWidth])
            Rectangle([borderWidth, maximum.y - minimum.y])
        }
            .offset(amount: 0.001, style: .miter)
        Union {
            half.translated(minimum)
            half.flipped(along: .all)
                .translated(maximum)
        }
        .colored(visualizationBorderColor)
        .background()
    }
}

public extension BoundingBox3D {
    func visualized(scale: Double = 1.0) -> any Geometry3D {
        let borderWidth = visualizationStandardBorderWidth * scale
        let size = maximum - minimum

        func frame(_ size: Vector2D) -> any Geometry3D {
            Rectangle(size)
                .offset(amount: 0.001, style: .bevel)
                .subtracting {
                    Rectangle(size)
                        .offset(amount: -borderWidth, style: .miter)
                }
                .extruded(height: borderWidth)
        }

        let half = Union {
            frame([size.x, size.y])
            frame([size.x, size.z])
                .rotated(x: 90°)
                .translated(y: borderWidth)
            frame([size.z, size.y])
                .rotated(y: -90°)
                .translated(x: borderWidth)
        }

        return half
            .translated(minimum)
            .adding {
                half.flipped(along: .all)
                    .translated(maximum)
            }
            .colored(visualizationBorderColor)
            .background()
    }
}

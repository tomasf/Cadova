import Foundation

public extension Geometry3D {
    func visualizingAxes(scale: Double = 1, length: Double = 10) -> any Geometry3D {
        let arrow = Cylinder(diameter: 0.1, height: length)
            .adding {
                Cylinder(bottomDiameter: 0.2, topDiameter: 0, height: 0.2)
                    .translated(z: length)
            }

        return self.adding {
            Box(0.2, center: .all)
                .colored(.white)
                .adding {
                    arrow.rotated(y: 90°)
                        .colored(.red)
                    arrow.rotated(x: -90°)
                        .colored(.green)
                    arrow
                        .colored(.blue)
                }
                .scaled(scale)
                .usingFacets(count: 8)
        }
    }
}

public extension Geometry2D {
    func visualizingAxes(scale: Double = 1, length: Double = 10) -> any Geometry2D {
        let arrow = Rectangle([length - 0.1, 0.1], center: .y)
            .translated(x: 0.1)
            .adding {
                Polygon([[0, 0.1], [0.2, 0], [0, -0.1]])
                    .translated(x: length)
            }

        return self.adding {
            Rectangle(0.2, center: .all)
                .colored(.white)
                .adding {
                    arrow
                        .colored(.red)
                    arrow.rotated(90°)
                        .colored(.green)
                }
                .scaled(scale)
        }
    }
}

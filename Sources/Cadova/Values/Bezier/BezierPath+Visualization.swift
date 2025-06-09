import Foundation

extension BezierPath {
    /// Visualizes the bezier path for debugging purposes by generating a 3D representation. This method creates visual markers for control points and start points, and lines to represent the path and its control lines.
    /// - Parameters:
    ///   - scale: A value that scales the size of markers and the thickness of lines.
    ///   - markerRotation: The rotation to use for markers. Set to nil to hide them.

    public func visualized(
        scale: Double = 1,
        markerRotation: Angle? = -45°
    ) -> any Geometry3D {
        @Sendable @GeometryBuilder3D
        func makeMarker(at location: V, text: String, transform: Transform3D) -> any Geometry3D {
            Union {
                Sphere(radius: 0.2)
                    .colored(.black)

                Text(text)
                    .measuringBounds { text, bounds in
                        Box(x: bounds.size.x + 1.0, y: 2, z: 0.1)
                            .applyingEdgeProfile(.fillet(radius: 1), along: .z)
                            .aligned(at: .center)
                            .colored(.white)
                            .adding {
                                text.extruded(height: 0.01)
                                    .translated(z: 0.1)
                                    .colored(.black)
                            }
                            .translated(y: 1)
                    }
            }
            .transformed(transform)
            .translated(location.vector3D)
        }

        @Sendable func makeMarker(at location: V, curveIndex: Int, pointIndex: Int, transform: Transform3D) -> any Geometry3D {
            makeMarker(at: location, text: "c\(curveIndex + 1)p\(pointIndex + 1)", transform: transform)
        }

        @Sendable func makeLine(from: V, to: V, thickness: Double) -> any Geometry3D {
            Sphere(diameter: thickness)
                .translated(from.vector3D)
                .adding {
                    Sphere(radius: thickness)
                        .translated(to.vector3D)
                }
                .convexHull()
                .withSegmentation(count: 3)
        }

        return readEnvironment { environment -> any Geometry3D in
            if let markerRotation {
                let transform = Transform3D.scaling(scale).rotated(x: 45°, z: markerRotation)
                for (curveIndex, curve) in curves.enumerated() {
                    for (pointIndex, controlPoint) in curve.controlPoints.dropFirst().enumerated() {
                        makeMarker(at: controlPoint, curveIndex: curveIndex, pointIndex: pointIndex, transform: transform)
                    }
                }
                makeMarker(at: startPoint, text: "Start", transform: transform)
            }

            // Lines between control points
            for curve in curves {
                for (cp1, cp2) in curve.controlPoints.paired() {
                    makeLine(from: cp1, to: cp2, thickness: 0.08 * scale)
                        .colored(.red, alpha: 0.2)
                }
            }

            // Curves
            Circle(radius: 0.1 * scale)
                .swept(along: self)
                .colored(.blue)
        }
        .withFontSize(1.5)
        .withTextAlignment(horizontal: .center, vertical: .center)
        .inPart(named: "Visualized Path", type: .visual)
    }
}

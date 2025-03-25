import Foundation

/// A `CylinderBridge` shape that represents a bridging structure within a 3D-printed object.
///
/// Bridging is a technique used in 3D printing to connect two points without support material. The `CylinderBridge` represents a bridged shape between two cylindrical diameters.
///
/// This can be particularly useful in scenarios where a model requires a cylindrical cavity with an overhang. By using this bridged structure, it helps to print the overhang without the need for additional supports.
///
/// ```
/// // Example of creating a cylinder bridge with a bottom diameter of 20 and a top diameter of 10.
/// let cylinderBridge = CylinderBridge(bottomDiameter: 20, topDiameter: 10)
/// ```
public struct CylinderBridge: Shape2D {
    let topDiameter: Double
    let bottomDiameter: Double

    /// Creates a cylinder bridge shape with specific bottom and top diameters.
    /// - Parameters:
    ///   - bottomDiameter: The diameter of the bottom part of the bridged cylinder.
    ///   - topDiameter: The diameter of the top part of the bridged cylinder.
    /// - Warning: Bridging where the top diameter is less than half the bottom diameter may not work optimally.
    public init(bottomDiameter: Double, topDiameter: Double) {
        assert(bottomDiameter > topDiameter, "The bottom diameter should be larger than the top diameter")
        if topDiameter < bottomDiameter / 2.0 {
            logger.warning("Bridging where the top diameter is less than half the bottom diameter may not work optimally.")
        }
        self.bottomDiameter = bottomDiameter
        self.topDiameter = topDiameter
    }

    private func regularPolygonSideCount(inscribedDiameter: Double, circumscribedDiameter: Double) -> Double {
        .pi / acos(inscribedDiameter / circumscribedDiameter)
    }

    private var sideCount: Int {
        let target = regularPolygonSideCount(inscribedDiameter: topDiameter, circumscribedDiameter: bottomDiameter)
        return max(Int(floor(target)), 3)
    }

    public var body: any Geometry2D {
        Circle(diameter: bottomDiameter)
            .subtracting {
                Rectangle([bottomDiameter, bottomDiameter])
                    .aligned(at: .centerY)
                    .translated(x: topDiameter / 2)
                    .repeated(in: 0°..<360°, count: sideCount)
            }
    }
}

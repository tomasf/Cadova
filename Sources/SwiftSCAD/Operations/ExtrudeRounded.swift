import Foundation

public extension Geometry2D {
    @UnionBuilder3D private func extrudedLayered(height: Double, topRadius radius: Double, layerHeight: Double) -> any Geometry3D {
        let layerCount = Int(ceil(radius / layerHeight))
        let effectiveRadius = Double(layerCount) * layerHeight

        for l in 0..<layerCount {
            let z = Double(l) * layerHeight
            offset(amount: (cos(asin(z / radius) as Angle) - 1) * radius, style: .round)
                .extruded(height: height - effectiveRadius + z + layerHeight)
        }
    }

    @UnionBuilder3D private func extrudedConvex(height: Double, topRadius radius: Double) -> any Geometry3D {
        EnvironmentReader3D { environment in
            let facetCount = environment.facets.facetCount(circleRadius: radius)

            let slices = (0...facetCount).mapUnion { f in
                let angle = (Double(f) / Double(facetCount)) * 90°
                let inset = cos(angle) * radius - radius
                let zOffset = sin(angle) * radius
                offset(amount: inset, style: .round)
                    .extruded(height: height - radius + zOffset)
            }

            return slices.convexHull()
        }
    }

    @UnionBuilder3D private func extruded(height: Double, topRadius radius: Double, method: ExtrusionMethod) -> any Geometry3D {
        switch method {
        case .layered (let layerHeight):
            extrudedLayered(height: height, topRadius: radius, layerHeight: layerHeight)
        case .convexHull:
            extrudedConvex(height: height, topRadius: radius)
        }
    }

    /// Extrudes a 2D geometry into a 3D shape with a specified top radius.
    ///
    /// This method allows you to create a 3D shape by extruding the 2D geometry.
    /// The top radius parameter enables a smooth transition to the top surface.
    /// The method of extrusion can be selected based on the desired characteristics
    /// of the resulting shape.
    ///
    /// - Parameters:
    ///   - height: The height of the extrusion.
    ///   - radius: The top radius of the extrusion.
    ///   - method: The method of extrusion, either `.layered(thickness:)` or `.convexHull`.
    ///     - `.layered`: This method divides the extrusion into distinct layers with a given thickness. While less elegant and more expensive to render, it is suitable for non-convex shapes. Layers work well for 3D printing, as the printing process inherently occurs in layers.
    ///     - `.convexHull`: This method creates a smooth, non-layered shape. It is computationally less intensive and results in a more aesthetically pleasing form but is only applicable for convex shapes.
    ///   - sides: Specifies which sides to chamfer (top, bottom, or both).
    /// - Returns: The extruded 3D geometry.
    func extruded(height: Double, radius: Double, method: ExtrusionMethod, sides: ExtrusionZSides = .top) -> any Geometry3D {
        switch sides {
        case .top:
            return extruded(height: height, topRadius: radius, method: method)
        case .bottom:
            return extruded(height: height, topRadius: radius, method: method)
                .scaled(z: -1)
                .translated(z: height)
        case .both:
            return Union {
                extruded(height: height / 2, radius: radius, method: method, sides: .top)
                    .translated(z: height / 2)
                extruded(height: height / 2, radius: radius, method: method, sides: .bottom)
            }
        }
    }
}

public extension Geometry2D {
    @available(*, deprecated, message: "Use extruded(height:radius:method:sides:) with .layered method instead")
    func extruded(height: Double, radius: Double, layerHeight: Double, sides: ExtrusionZSides = .top) -> any Geometry3D {
        extruded(height: height, radius: radius, method: .layered(height: layerHeight), sides: sides)
    }
}

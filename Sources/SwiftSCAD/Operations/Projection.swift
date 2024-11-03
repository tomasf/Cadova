import Foundation

struct Projection: Geometry2D {
    let body: any Geometry3D
    let mode: Mode

    enum Mode {
        case whole
        case slice (z: Double)
    }

    private var parameters: CodeFragment.Parameters {
        switch mode {
        case .whole: [:]
        case .slice: ["cut": true]
        }
    }

    private var appliedBody: any Geometry3D {
        switch mode {
        case .whole: body
        case .slice (let z): body.translated(z: -z)
        }
    }

    func evaluated(in environment: Environment) -> Output2D {
        let environment = environment.applyingTransform(.scaling(z: 0))
        let bodyOutput = appliedBody.evaluated(in: environment)
        return .init(
            codeFragment: .init(module: "projection", parameters: parameters, body: [bodyOutput.codeFragment]),
            boundary: bodyOutput.boundary.map(\.xy),
            elements: bodyOutput.elements
        )
    }
}

public extension Geometry3D {
    /// Projects the 3D geometry onto a 2D plane.
    /// - Returns: A `Geometry2D` representing the projected shape.
    /// - Example:
    ///   ```
    ///   let sphere = Sphere(radius: 10)
    ///   let projectedSphere = sphere.projection()
    ///   ```
    func projection() -> any Geometry2D {
        Projection(body: self, mode: .whole)
    }

    /// Projects the 3D geometry onto a 2D plane, slicing at a specific Z value.
    /// The slicing at Z creates a 2D cross-section of the geometry at that Z height.
    /// - Parameter slicingAtZ: The Z value at which the geometry will be sliced when projecting. It defines the height at which the cross-section is taken.
    /// - Returns: A `Geometry2D` representing the projected shape.
    /// - Example:
    ///   ```swift
    ///   let truncatedCone = Cylinder(bottomDiameter: 10, topDiameter: 5, height: 15)
    ///   let slicedProjection = truncatedCone.projection(slicingAtZ: 5)
    ///   // The result will be a circle with a diameter that represents the cross-section of the truncated cone at Z = 5.
    ///   ```
    func projection(slicingAtZ z: Double) -> any Geometry2D {
        Projection(body: self, mode: .slice(z: z))
    }
}

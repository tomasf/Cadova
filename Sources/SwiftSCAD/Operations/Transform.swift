import Foundation

struct Transform3D: CoreGeometry3D {
	let transform: AffineTransform
	let body: Geometry3D

	func call(in environment: Environment) -> SCADCall {
		SCADCall(
			name: "multmatrix",
			params: ["m": transform],
			body: body
		)
	}
}

public extension Geometry3D {
	func transformed(_ transform: AffineTransform) -> Geometry3D {
		Transform3D(transform: transform, body: self)
	}

	func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> Geometry3D {
		transformed(.shearing(axis, along: otherAxis, factor: factor))
	}

	func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> Geometry3D {
		transformed(.shearing(axis, along: otherAxis, angle: angle))
	}
}


struct Transform2D: CoreGeometry2D {
    let transform: AffineTransform2D
    let body: Geometry2D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(
            name: "multmatrix",
            params: ["m": AffineTransform(transform)],
            body: body
        )
    }
}

public extension Geometry2D {
    func transformed(_ transform: AffineTransform2D) -> Geometry2D {
        Transform2D(transform: transform, body: self)
    }

    func sheared(_ axis: Axis2D, along otherAxis: Axis2D, factor: Double) -> Geometry2D {
        transformed(.shearing(axis, along: otherAxis, factor: factor))
    }

    func sheared(_ axis: Axis2D, along otherAxis: Axis2D, angle: Angle) -> Geometry2D {
        transformed(.shearing(axis, along: otherAxis, angle: angle))
    }
}

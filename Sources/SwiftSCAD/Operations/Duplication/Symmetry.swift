import Foundation

public extension Geometry3D {
	@UnionBuilder func symmetry(over axes: Axes3D) -> Geometry3D {
		for xs in axes.contains(.x) ? [1.0, -1.0] : [1.0] {
			for ys in axes.contains(.y) ? [1.0, -1.0] : [1.0] {
				for zs in axes.contains(.z) ? [1.0, -1.0] : [1.0] {
					scaled(x: xs, y: ys, z: zs)
				}
			}
		}
	}
}


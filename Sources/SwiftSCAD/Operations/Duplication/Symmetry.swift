import Foundation

public extension Geometry3D {
	func symmetry(over axes: Axes3D) -> Geometry3D {
		ForEach(axes.contains(.x) ? [1.0, -1.0] : [1.0]) { xs in
			ForEach(axes.contains(.y) ? [1.0, -1.0] : [1.0]) { ys in
				ForEach(axes.contains(.z) ? [1.0, -1.0] : [1.0]) { zs in
					self.scaled(x: xs, y: ys, z: zs)
				}
			}
		}
	}
}


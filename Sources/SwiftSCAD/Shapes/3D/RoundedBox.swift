import Foundation

public struct RoundedBox: Shape3D {
	internal typealias CornerRadii = RoundedRectangle.CornerRadii
	private let implementation: Geometry3D
	
	// Single axis
	private init(size: Vector3D, center: Axes3D, axis: Axis3D, cornerRadii radii: CornerRadii) {
		self.implementation = RoundedBoxSingleAxis(size: size, axis: axis, radii: radii)
			.translated((size / 2).setting(axes: center, to: 0))
	}
	
	public init(size: Vector3D, center: Axes3D = [], axis: Axis3D, cornerRadius: Double) {
		self.init(size: size, center: center, axis: axis, cornerRadii: .init(cornerRadius))
	}
	
	public init(size: Vector3D, center: Axes3D = [], axis: Axis3D, cornerRadii radii: [Double]) {
		precondition(radii.count == 4)
		self.init(size: size, center: center, axis: axis, cornerRadii: .init(arrayLiteral: radii[0], radii[1], radii[2], radii[3]))
	}
	
	// 3D
	public init(size: Vector3D, center: Axes3D = [], cornerRadius radius: Double) {
		self.implementation = RoundedBox3D(size: size, cornerRadius: radius)
			.translated((size / 2).setting(axes: center, to: 0))
	}
	
	public var body: Geometry3D {
		implementation
	}
}

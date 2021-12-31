import Foundation

public struct RoundedBox: Shape3D {
	internal typealias CornerRadii = RoundedRectangle.CornerRadii
	public typealias CornerStyle = RoundedRectangle.CornerStyle
	private let implementation: Geometry3D
	
	// Single axis
	private init(_ size: Vector3D, center: Axes3D, axis: Axis3D, style: CornerStyle, cornerRadii radii: CornerRadii) {
		self.implementation = RoundedBoxSingleAxis(size: size, cornerStyle: style, axis: axis, radii: radii)
			.translated((size / 2).setting(axes: center, to: 0))
	}
	
	public init(_ size: Vector3D, center: Axes3D = [], axis: Axis3D, style: CornerStyle = .circular, cornerRadius: Double) {
		self.init(size, center: center, axis: axis, style: style, cornerRadii: .init(cornerRadius))
	}
	
	public init(_ size: Vector3D, center: Axes3D = [], axis: Axis3D, style: CornerStyle = .circular, cornerRadii radii: [Double]) {
		precondition(radii.count == 4)
		self.init(size, center: center, axis: axis, style: style, cornerRadii: .init(arrayLiteral: radii[0], radii[1], radii[2], radii[3]))
	}
	
	// 3D
	public init(_ size: Vector3D, center: Axes3D = [], cornerRadius radius: Double) {
		self.implementation = RoundedBox3D(size: size, cornerRadius: radius)
			.translated((size / 2).setting(axes: center, to: 0))
	}
	
	public var body: Geometry3D {
		implementation
	}
}

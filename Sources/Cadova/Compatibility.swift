import Foundation

public extension Geometry3D {
    @available(*, deprecated, message: "Use Model instead.")
    func save(to path: String) async {
        await Model(path, content: { self })
    }
}

public extension Geometry2D {
    @available(*, deprecated, message: "Use Model instead.")
    func save(to path: String) async {
        await Model(path, content: { self })
    }
}

@available(*, deprecated, message: "Use Mesh instead of Polyhedron.")
public typealias Polyhedron = Mesh

public extension Geometry2D {
    @available(*, deprecated, renamed: "revolved(in:)")
    func extruded(angles: Range<Angle> = 0°..<360°) -> any Geometry3D {
        revolved(in: angles)
    }
}

public extension Geometry {
    @available(*, deprecated, renamed: "flipped(across:)")
    func flipped(along axes: D.Axes) -> D.Geometry {
        flipped(across: axes)
    }
}

public extension Teardrop {
    @available(*, deprecated, message: "Use the `withOverhangAngle` modifier to specify an angle for Teardrop", renamed: "init(diameter:style:)")
    init(diameter: Double, angle: Angle, style: Style = .pointed) {
        self.init(diameter: diameter, style: style)
    }

    @available(*, deprecated, message: "Use the `withOverhangAngle` modifier to specify an angle for Teardrop", renamed: "init(radius:style:)")
    init(radius: Double, angle: Angle = 45°, style: Style = .pointed) {
        self.init(radius: radius, style: style)
    }
}

extension Teardrop.Style {
    @available(*, deprecated, renamed: "pointed")
    static let full = Self.pointed
    @available(*, deprecated, renamed: "flat")
    static let bridged = Self.flat
}

@available(*, deprecated, renamed: "Transform2D")
public typealias AffineTransform2D = Transform2D

@available(*, deprecated, renamed: "Transform3D")
public typealias AffineTransform3D = Transform3D
